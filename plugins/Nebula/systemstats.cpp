#include "systemstats.h"

#include <QDateTime>
#include <QDir>
#include <QFile>

#include <sys/statvfs.h>

namespace {

constexpr qreal kGiB = 1024.0 * 1024.0 * 1024.0;

QByteArray readFile(const QString &path)
{
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly))
        return {};
    return f.readAll();
}

bool readNumber(const QString &path, qreal &out)
{
    const QByteArray data = readFile(path).trimmed();
    if (data.isEmpty())
        return false;
    bool ok = false;
    const qreal v = data.toDouble(&ok);
    if (ok)
        out = v;
    return ok;
}

template <typename T>
bool assign(T &field, const T &value)
{
    if (field == value)
        return false;
    field = value;
    return true;
}

quint64 field(const QList<QByteArray> &parts, int i)
{
    return i < parts.size() ? parts.at(i).toULongLong() : 0;
}

}

struct StatsData {
    struct CpuTimes { quint64 total = 0; quint64 idle = 0; };
    QString m_cpuName;
    bool m_havePrevCpu = false;
    CpuTimes m_prevCpu;
    QList<CpuTimes> m_prevCores;
    qreal m_cpuUsage = 0;
    QVariantList m_cpuCores;
    qreal m_cpuTemp = 0;

    qreal m_memUsage = 0;
    qreal m_memUsedGb = 0;
    qreal m_memTotalGb = 0;
    qreal m_memCacheFrac = 0;
    qreal m_memBuffersFrac = 0;

    qreal m_gpuUsage = 0;
    qreal m_gpuTemp = 0;
    qreal m_gpuVramUsage = 0;
    qreal m_gpuVramUsedGb = 0;
    qreal m_gpuVramTotalGb = 0;
    qreal m_gpuClockMhz = 0;

    qreal m_diskUsage = 0;
    qreal m_diskUsedGb = 0;
    qreal m_diskTotalGb = 0;

    bool m_havePrevNet = false;
    qreal m_prevRx = 0;
    qreal m_prevTx = 0;
    qint64 m_lastNetMs = 0;
    qreal m_netDown = 0;
    qreal m_netUp = 0;
    qreal m_netRx = 0;
    qreal m_netTx = 0;
};
Q_DECLARE_METATYPE(StatsData)

class StatsWorker : public QObject, public StatsData
{
    Q_OBJECT
public:
    void initialize();
    void resolvePaths();
    void sampleStats();
    void sampleCpu();
    void sampleMem();
    void sampleTemps();
    void sampleGpu();
    void sampleNet();
    void sampleDisk();
    void resetNetBaseline() { m_havePrevNet = false; m_lastNetMs = 0; }
    QString m_netInterface;
    int m_netInterval = 2000;
    QString m_cpuTempPath, m_gpuDevicePath, m_gpuHwmonPath;
signals:
    void sampled(const StatsData &data, int kind, quint64 generation);
};

SystemStats::SystemStats(QObject *parent)
    : QObject(parent), m_worker(new StatsWorker), m_thread(new QThread)
{
    m_statsTimer.setInterval(4000);
    m_netTimer.setInterval(2000);
    m_diskTimer.setInterval(30000);
    connect(&m_statsTimer, &QTimer::timeout, this, &SystemStats::sampleStats);
    connect(&m_netTimer, &QTimer::timeout, this, &SystemStats::sampleNet);
    connect(&m_diskTimer, &QTimer::timeout, this, &SystemStats::sampleDisk);
    qRegisterMetaType<StatsData>();
    m_worker->moveToThread(m_thread);
    connect(m_thread, &QThread::started, m_worker, &StatsWorker::initialize);
    connect(m_worker, &StatsWorker::sampled, this, &SystemStats::applySample);
    connect(m_thread, &QThread::finished, m_worker, &QObject::deleteLater);
    connect(m_thread, &QThread::finished, m_thread, &QObject::deleteLater);
    m_thread->start();
}

SystemStats::~SystemStats()
{
    m_thread->quit();
}

void SystemStats::setRunning(bool running)
{
    if (m_running == running)
        return;
    m_running = running;
    if (running) {
        m_statsTimer.start();
        m_netTimer.start();
        m_diskTimer.start();
        sampleNow();
    } else {
        m_statsTimer.stop();
        m_netTimer.stop();
        m_diskTimer.stop();
        resetNetBaseline();
    }
    emit runningChanged();
}

void SystemStats::setInterval(int ms)
{
    ms = qMax(250, ms);
    if (m_statsTimer.interval() == ms)
        return;
    m_statsTimer.setInterval(ms);
    emit intervalChanged();
}

void SystemStats::setNetInterval(int ms)
{
    ms = qMax(250, ms);
    if (m_netTimer.interval() == ms)
        return;
    m_netTimer.setInterval(ms);
    emit netIntervalChanged();
}

void SystemStats::setDiskInterval(int ms)
{
    ms = qMax(1000, ms);
    if (m_diskTimer.interval() == ms)
        return;
    m_diskTimer.setInterval(ms);
    emit diskIntervalChanged();
}

void SystemStats::setNetInterface(const QString &iface)
{
    if (m_netInterface == iface)
        return;
    m_netInterface = iface;
    resetNetBaseline();
    m_netDown = 0;
    m_netUp = 0;
    m_netRx = 0;
    m_netTx = 0;
    emit netChanged();
    emit netInterfaceChanged();
}

void SystemStats::resetNetBaseline()
{
    ++m_netGeneration;
    QMetaObject::invokeMethod(m_worker, [worker = m_worker] { worker->resetNetBaseline(); }, Qt::QueuedConnection);
}

void SystemStats::sampleNow()
{
    sampleStats();
    sampleNet();
    sampleDisk();
}

void SystemStats::sampleStats() { requestSample(0); }
void SystemStats::sampleNet() { requestSample(1); }
void SystemStats::sampleDisk() { requestSample(2); }

void SystemStats::requestSample(int kind)
{
    if (m_pending[kind])
        return;
    m_pending[kind] = true;
    const QString iface = m_netInterface;
    const int interval = m_netTimer.interval();
    const quint64 generation = m_netGeneration;
    QMetaObject::invokeMethod(m_worker, [worker = m_worker, kind, iface, interval, generation] {
        if (kind == 0) worker->sampleStats();
        else if (kind == 1) {
            if (worker->m_netInterface != iface) {
                worker->m_netDown = worker->m_netUp = 0;
                worker->m_netRx = worker->m_netTx = 0;
            }
            worker->m_netInterface = iface;
            worker->m_netInterval = interval;
            worker->sampleNet();
        } else worker->sampleDisk();
        emit worker->sampled(*worker, kind, generation);
    }, Qt::QueuedConnection);
}

void SystemStats::applySample(const StatsData &data, int kind, quint64 generation)
{
    if (kind >= 0) m_pending[kind] = false;
    if (kind == 1 && generation != m_netGeneration) {
        if (m_running)
            sampleNet();
        return;
    }
    if (kind == -1) {
        bool changed = false;
        changed |= assign(m_cpuName, data.m_cpuName);
        if (changed) emit cpuNameChanged();
        changed = false;
        changed |= assign(m_gpuVramTotalGb, data.m_gpuVramTotalGb);
        if (changed) emit gpuChanged();
    }
    if (kind == 0) {
        bool changed = false;
        changed |= assign(m_cpuUsage, data.m_cpuUsage);
        changed |= assign(m_cpuCores, data.m_cpuCores);
        if (changed) emit cpuChanged();
        changed = false;
        changed |= assign(m_cpuTemp, data.m_cpuTemp);
        if (changed) emit cpuTempChanged();
        changed = false;
        changed |= assign(m_memUsage, data.m_memUsage);
        changed |= assign(m_memUsedGb, data.m_memUsedGb);
        changed |= assign(m_memTotalGb, data.m_memTotalGb);
        changed |= assign(m_memCacheFrac, data.m_memCacheFrac);
        changed |= assign(m_memBuffersFrac, data.m_memBuffersFrac);
        if (changed) emit memChanged();
        changed = false;
        changed |= assign(m_gpuUsage, data.m_gpuUsage);
        changed |= assign(m_gpuTemp, data.m_gpuTemp);
        changed |= assign(m_gpuVramUsage, data.m_gpuVramUsage);
        changed |= assign(m_gpuVramUsedGb, data.m_gpuVramUsedGb);
        changed |= assign(m_gpuVramTotalGb, data.m_gpuVramTotalGb);
        changed |= assign(m_gpuClockMhz, data.m_gpuClockMhz);
        if (changed) emit gpuChanged();
    }
    if (kind == 1) {
        bool changed = false;
        changed |= assign(m_netDown, data.m_netDown);
        changed |= assign(m_netUp, data.m_netUp);
        changed |= assign(m_netRx, data.m_netRx);
        changed |= assign(m_netTx, data.m_netTx);
        if (changed) emit netChanged();
        emit netSampled();
    }
    if (kind == 2) {
        bool changed = false;
        changed |= assign(m_diskUsage, data.m_diskUsage);
        changed |= assign(m_diskUsedGb, data.m_diskUsedGb);
        changed |= assign(m_diskTotalGb, data.m_diskTotalGb);
        if (changed) emit diskChanged();
    }
}

void StatsWorker::initialize()
{
    resolvePaths();

    const QList<QByteArray> lines = readFile(QStringLiteral("/proc/cpuinfo")).split('\n');
    for (const QByteArray &line : lines) {
        if (line.startsWith("model name")) {
            const int sep = line.indexOf(':');
            if (sep >= 0)
                m_cpuName = QString::fromUtf8(line.mid(sep + 1).trimmed());
            break;
        }
    }

    qreal vramTotal = 0;
    if (!m_gpuDevicePath.isEmpty() && readNumber(m_gpuDevicePath + QStringLiteral("/mem_info_vram_total"), vramTotal))
        m_gpuVramTotalGb = vramTotal / kGiB;
    emit sampled(*this, -1, 0);
}

void StatsWorker::resolvePaths()
{
    static const QStringList cpuSensors = {
        QStringLiteral("k10temp"), QStringLiteral("zenpower"),
        QStringLiteral("coretemp"), QStringLiteral("cpu_thermal"),
    };

    const QDir hwmonRoot(QStringLiteral("/sys/class/hwmon"));
    for (const QString &entry : hwmonRoot.entryList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name)) {
        const QString dir = hwmonRoot.filePath(entry);
        const QString name = QString::fromUtf8(readFile(dir + QStringLiteral("/name")).trimmed());
        if (m_cpuTempPath.isEmpty() && cpuSensors.contains(name) && QFile::exists(dir + QStringLiteral("/temp1_input")))
            m_cpuTempPath = dir + QStringLiteral("/temp1_input");
    }

    const QDir drmRoot(QStringLiteral("/sys/class/drm"));
    for (const QString &entry : drmRoot.entryList({QStringLiteral("card*")}, QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name)) {
        if (entry.contains(QLatin1Char('-')))
            continue;
        const QString device = drmRoot.filePath(entry) + QStringLiteral("/device");
        if (!QFile::exists(device + QStringLiteral("/gpu_busy_percent")))
            continue;
        m_gpuDevicePath = device;
        const QDir hw(device + QStringLiteral("/hwmon"));
        const QStringList hws = hw.entryList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);
        if (!hws.isEmpty())
            m_gpuHwmonPath = hw.filePath(hws.first());
        break;
    }
}

void StatsWorker::sampleStats()
{
    sampleCpu();
    sampleMem();
    sampleTemps();
    sampleGpu();
}

void StatsWorker::sampleCpu()
{
    const QList<QByteArray> lines = readFile(QStringLiteral("/proc/stat")).split('\n');
    if (lines.isEmpty() || !lines.first().startsWith("cpu"))
        return;

    auto parse = [](const QByteArray &line) {
        const QList<QByteArray> p = line.simplified().split(' ');
        CpuTimes t;
        const quint64 idle = field(p, 4);
        const quint64 iowait = field(p, 5);
        t.total = field(p, 1) + field(p, 2) + field(p, 3) + idle + iowait + field(p, 6) + field(p, 7);
        t.idle = idle + iowait;
        return t;
    };

    const CpuTimes all = parse(lines.first());
    if (m_havePrevCpu) {
        const qreal dt = qreal(all.total) - qreal(m_prevCpu.total);
        const qreal di = qreal(all.idle) - qreal(m_prevCpu.idle);
        m_cpuUsage = dt > 0 ? (dt - di) / dt : 0.0;
    }
    m_prevCpu = all;
    m_havePrevCpu = true;

    QList<CpuTimes> next;
    QVariantList cores;
    for (int i = 1; i < lines.size() && lines.at(i).startsWith("cpu"); i++) {
        const CpuTimes t = parse(lines.at(i));
        const int idx = next.size();
        next.append(t);
        if (idx < m_prevCores.size()) {
            const CpuTimes &pc = m_prevCores.at(idx);
            const qreal dt = qreal(t.total) - qreal(pc.total);
            const qreal di = qreal(t.idle) - qreal(pc.idle);
            cores.append(dt > 0 ? (dt - di) / dt : 0.0);
        }
    }
    m_prevCores = next;
    if (!cores.isEmpty())
        m_cpuCores = cores;

}

void StatsWorker::sampleMem()
{
    const QList<QByteArray> lines = readFile(QStringLiteral("/proc/meminfo")).split('\n');
    qreal total = 0, available = 0, cached = 0, reclaim = 0, buffers = 0;
    auto value = [](const QByteArray &line) {
        return line.simplified().split(' ').value(1).toDouble();
    };
    for (const QByteArray &line : lines) {
        if (line.startsWith("MemTotal:"))
            total = value(line);
        else if (line.startsWith("MemAvailable:"))
            available = value(line);
        else if (line.startsWith("Cached:"))
            cached = value(line);
        else if (line.startsWith("SReclaimable:"))
            reclaim = value(line);
        else if (line.startsWith("Buffers:"))
            buffers = value(line);
    }

    m_memCacheFrac = total > 0 ? qMin(available, cached + reclaim) / total : 0.0;
    m_memBuffersFrac = total > 0 ? buffers / total : 0.0;
    m_memTotalGb = total / (1024.0 * 1024.0);
    m_memUsedGb = (total - available) / (1024.0 * 1024.0);
    m_memUsage = total > 0 ? (total - available) / total : 0.0;
}

void StatsWorker::sampleTemps()
{
    qreal v = 0;
    if (!m_cpuTempPath.isEmpty() && readNumber(m_cpuTempPath, v))
        m_cpuTemp = v / 1000.0;
}

void StatsWorker::sampleGpu()
{
    if (m_gpuDevicePath.isEmpty())
        return;

    qreal v = 0;
    if (readNumber(m_gpuDevicePath + QStringLiteral("/gpu_busy_percent"), v))
        m_gpuUsage = v / 100.0;
    if (!m_gpuHwmonPath.isEmpty()) {
        if (readNumber(m_gpuHwmonPath + QStringLiteral("/temp1_input"), v))
            m_gpuTemp = v / 1000.0;
        if (readNumber(m_gpuHwmonPath + QStringLiteral("/freq1_input"), v))
            m_gpuClockMhz = v / 1000000.0;
    }
    if (readNumber(m_gpuDevicePath + QStringLiteral("/mem_info_vram_used"), v)) {
        m_gpuVramUsedGb = v / kGiB;
        if (m_gpuVramTotalGb > 0)
            m_gpuVramUsage = v / (m_gpuVramTotalGb * kGiB);
    }
}

void StatsWorker::sampleNet()
{
    auto clearReadings = [this] {
        m_netDown = 0;
        m_netUp = 0;
    };

    if (m_netInterface.isEmpty()) {
        resetNetBaseline();
        clearReadings();
        return;
    }

    const QByteArray prefix = m_netInterface.toUtf8() + ':';
    qreal rx = -1, tx = -1;
    const QList<QByteArray> lines = readFile(QStringLiteral("/proc/net/dev")).split('\n');
    for (const QByteArray &raw : lines) {
        const QByteArray line = raw.trimmed();
        if (!line.startsWith(prefix))
            continue;
        const QList<QByteArray> parts = line.mid(prefix.size()).simplified().split(' ');
        if (parts.size() > 8) {
            rx = parts.at(0).toDouble();
            tx = parts.at(8).toDouble();
        }
        break;
    }

    if (rx < 0 || tx < 0) {
        resetNetBaseline();
        clearReadings();
        return;
    }

    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    const qreal dt = (now - m_lastNetMs) / 1000.0;
    const bool usable = m_havePrevNet && rx >= m_prevRx && tx >= m_prevTx && dt > 0
        && dt < (m_netInterval / 1000.0) * 3;

    if (usable) {
        m_netDown = (rx - m_prevRx) / dt;
        m_netUp = (tx - m_prevTx) / dt;
    } else {
        clearReadings();
    }
    m_netRx = rx;
    m_netTx = tx;

    m_prevRx = rx;
    m_prevTx = tx;
    m_havePrevNet = true;
    m_lastNetMs = now;

}

void StatsWorker::sampleDisk()
{
    struct statvfs s {};
    if (statvfs("/", &s) != 0)
        return;
    const qreal frsize = qreal(s.f_frsize);
    const qreal total = qreal(s.f_blocks) * frsize;
    const qreal used = qreal(s.f_blocks - s.f_bfree) * frsize;

    m_diskUsedGb = used / kGiB;
    m_diskTotalGb = total / kGiB;
    m_diskUsage = total > 0 ? used / total : 0.0;
}

#include "systemstats.moc"
