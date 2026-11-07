#pragma once

#include <QObject>
#include <QString>
#include <QTimer>
#include <QThread>
#include <QVariantList>
#include <QtQml/qqml.h>

class StatsWorker;
struct StatsData;

class SystemStats : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool running READ running WRITE setRunning NOTIFY runningChanged)
    Q_PROPERTY(int interval READ interval WRITE setInterval NOTIFY intervalChanged)
    Q_PROPERTY(int netInterval READ netInterval WRITE setNetInterval NOTIFY netIntervalChanged)
    Q_PROPERTY(int diskInterval READ diskInterval WRITE setDiskInterval NOTIFY diskIntervalChanged)
    Q_PROPERTY(QString netInterface READ netInterface WRITE setNetInterface NOTIFY netInterfaceChanged)

    Q_PROPERTY(QString cpuName READ cpuName NOTIFY cpuNameChanged)
    Q_PROPERTY(qreal cpuUsage READ cpuUsage NOTIFY cpuChanged)
    Q_PROPERTY(QVariantList cpuCores READ cpuCores NOTIFY cpuChanged)
    Q_PROPERTY(qreal cpuTemp READ cpuTemp NOTIFY cpuTempChanged)

    Q_PROPERTY(qreal memUsage READ memUsage NOTIFY memChanged)
    Q_PROPERTY(qreal memUsedGb READ memUsedGb NOTIFY memChanged)
    Q_PROPERTY(qreal memTotalGb READ memTotalGb NOTIFY memChanged)
    Q_PROPERTY(qreal memCacheFrac READ memCacheFrac NOTIFY memChanged)
    Q_PROPERTY(qreal memBuffersFrac READ memBuffersFrac NOTIFY memChanged)

    Q_PROPERTY(qreal gpuUsage READ gpuUsage NOTIFY gpuChanged)
    Q_PROPERTY(qreal gpuTemp READ gpuTemp NOTIFY gpuChanged)
    Q_PROPERTY(qreal gpuVramUsage READ gpuVramUsage NOTIFY gpuChanged)
    Q_PROPERTY(qreal gpuVramUsedGb READ gpuVramUsedGb NOTIFY gpuChanged)
    Q_PROPERTY(qreal gpuVramTotalGb READ gpuVramTotalGb NOTIFY gpuChanged)
    Q_PROPERTY(qreal gpuClockMhz READ gpuClockMhz NOTIFY gpuChanged)

    Q_PROPERTY(qreal diskUsage READ diskUsage NOTIFY diskChanged)
    Q_PROPERTY(qreal diskUsedGb READ diskUsedGb NOTIFY diskChanged)
    Q_PROPERTY(qreal diskTotalGb READ diskTotalGb NOTIFY diskChanged)

    Q_PROPERTY(qreal netDownloadBps READ netDownloadBps NOTIFY netChanged)
    Q_PROPERTY(qreal netUploadBps READ netUploadBps NOTIFY netChanged)
    Q_PROPERTY(qreal netTotalRxBytes READ netTotalRxBytes NOTIFY netChanged)
    Q_PROPERTY(qreal netTotalTxBytes READ netTotalTxBytes NOTIFY netChanged)

public:
    explicit SystemStats(QObject *parent = nullptr);
    ~SystemStats() override;

    bool running() const { return m_running; }
    void setRunning(bool running);
    int interval() const { return m_statsTimer.interval(); }
    void setInterval(int ms);
    int netInterval() const { return m_netTimer.interval(); }
    void setNetInterval(int ms);
    int diskInterval() const { return m_diskTimer.interval(); }
    void setDiskInterval(int ms);
    QString netInterface() const { return m_netInterface; }
    void setNetInterface(const QString &iface);

    QString cpuName() const { return m_cpuName; }
    qreal cpuUsage() const { return m_cpuUsage; }
    QVariantList cpuCores() const { return m_cpuCores; }
    qreal cpuTemp() const { return m_cpuTemp; }

    qreal memUsage() const { return m_memUsage; }
    qreal memUsedGb() const { return m_memUsedGb; }
    qreal memTotalGb() const { return m_memTotalGb; }
    qreal memCacheFrac() const { return m_memCacheFrac; }
    qreal memBuffersFrac() const { return m_memBuffersFrac; }

    qreal gpuUsage() const { return m_gpuUsage; }
    qreal gpuTemp() const { return m_gpuTemp; }
    qreal gpuVramUsage() const { return m_gpuVramUsage; }
    qreal gpuVramUsedGb() const { return m_gpuVramUsedGb; }
    qreal gpuVramTotalGb() const { return m_gpuVramTotalGb; }
    qreal gpuClockMhz() const { return m_gpuClockMhz; }

    qreal diskUsage() const { return m_diskUsage; }
    qreal diskUsedGb() const { return m_diskUsedGb; }
    qreal diskTotalGb() const { return m_diskTotalGb; }

    qreal netDownloadBps() const { return m_netDown; }
    qreal netUploadBps() const { return m_netUp; }
    qreal netTotalRxBytes() const { return m_netRx; }
    qreal netTotalTxBytes() const { return m_netTx; }

    Q_INVOKABLE void resetNetBaseline();
    Q_INVOKABLE void sampleNow();

signals:
    void runningChanged();
    void intervalChanged();
    void netIntervalChanged();
    void diskIntervalChanged();
    void netInterfaceChanged();
    void cpuNameChanged();
    void cpuChanged();
    void cpuTempChanged();
    void memChanged();
    void gpuChanged();
    void diskChanged();
    void netChanged();
    void netSampled();

private:
    void sampleStats();
    void sampleNet();
    void sampleDisk();

    bool m_running = false;
    QTimer m_statsTimer;
    QTimer m_netTimer;
    QTimer m_diskTimer;
    QString m_netInterface;

    StatsWorker *m_worker = nullptr;
    QThread *m_thread = nullptr;
    bool m_pending[3] = {};
    quint64 m_netGeneration = 0;
    void requestSample(int kind);
    void applySample(const StatsData &data, int kind, quint64 generation);

    QString m_cpuName;
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

    qreal m_netDown = 0;
    qreal m_netUp = 0;
    qreal m_netRx = 0;
    qreal m_netTx = 0;
};
