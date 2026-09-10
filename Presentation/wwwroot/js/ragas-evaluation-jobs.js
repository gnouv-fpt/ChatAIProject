(() => {
    const widget = document.querySelector('[data-ragas-job-widget]');
    if (!widget || !window.signalR) {
        return;
    }

    const endpoints = {
        current: '/RagasEvaluation/RunEvaluation?handler=Current',
        run: '/RagasEvaluation/RunEvaluation'
    };
    const jobs = new Map();
    const joined = new Set();
    let connection = null;
    let clockTimer = null;

    function value(payload, camelName, pascalName, fallbackValue = null) {
        if (payload && payload[camelName] !== undefined && payload[camelName] !== null) {
            return payload[camelName];
        }

        if (payload && payload[pascalName] !== undefined && payload[pascalName] !== null) {
            return payload[pascalName];
        }

        return fallbackValue;
    }

    function normalize(payload) {
        const evaluationId = value(payload, 'evaluationId', 'EvaluationId', '');
        return {
            evaluationId,
            userId: Number(value(payload, 'userId', 'UserId', 0)),
            subjectId: Number(value(payload, 'subjectId', 'SubjectId', 0)),
            subjectName: value(payload, 'subjectName', 'SubjectName', ''),
            status: value(payload, 'status', 'Status', ''),
            stage: value(payload, 'stage', 'Stage', ''),
            percent: Number(value(payload, 'percent', 'Percent', 0)),
            completedSteps: Number(value(payload, 'completedSteps', 'CompletedSteps', 0)),
            totalSteps: Number(value(payload, 'totalSteps', 'TotalSteps', 0)),
            currentModel: value(payload, 'currentModel', 'CurrentModel', ''),
            currentStrategy: value(payload, 'currentStrategy', 'CurrentStrategy', ''),
            currentQuestion: value(payload, 'currentQuestion', 'CurrentQuestion', null),
            totalQuestions: Number(value(payload, 'totalQuestions', 'TotalQuestions', 0)),
            elapsedSeconds: Number(value(payload, 'elapsedSeconds', 'ElapsedSeconds', 0)),
            estimatedRemainingSeconds: value(payload, 'estimatedRemainingSeconds', 'EstimatedRemainingSeconds', null),
            message: value(payload, 'message', 'Message', 'Đang chạy đánh giá...'),
            queuePosition: value(payload, 'queuePosition', 'QueuePosition', null),
            queuedJobsForUser: Number(value(payload, 'queuedJobsForUser', 'QueuedJobsForUser', 0)),
            enqueuedAt: value(payload, 'enqueuedAt', 'EnqueuedAt', null),
            startedAt: value(payload, 'startedAt', 'StartedAt', null),
            finishedAt: value(payload, 'finishedAt', 'FinishedAt', null),
            isCompleted: Boolean(value(payload, 'isCompleted', 'IsCompleted', false)),
            isFailed: Boolean(value(payload, 'isFailed', 'IsFailed', false)),
            receivedAt: Date.now()
        };
    }

    function isTerminal(job) {
        return job.isCompleted
            || job.isFailed
            || job.status === 'Completed'
            || job.status === 'Failed'
            || job.status === 'Cancelled';
    }

    function createEvaluationId() {
        const bytes = new Uint8Array(16);
        crypto.getRandomValues(bytes);
        return Array.from(bytes, item => item.toString(16).padStart(2, '0')).join('');
    }

    function formatDuration(totalSeconds) {
        if (totalSeconds === null || totalSeconds === undefined || !Number.isFinite(totalSeconds)) {
            return 'Đang tính...';
        }

        const seconds = Math.max(0, Math.floor(totalSeconds));
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);
        const remainingSeconds = seconds % 60;

        if (hours > 0) {
            return String(hours).padStart(2, '0')
                + ':' + String(minutes).padStart(2, '0')
                + ':' + String(remainingSeconds).padStart(2, '0');
        }

        return String(minutes).padStart(2, '0') + ':' + String(remainingSeconds).padStart(2, '0');
    }

    function selectVisibleJob() {
        const allJobs = Array.from(jobs.values());
        if (allJobs.length === 0) {
            return null;
        }

        return allJobs.find(job => job.status === 'Running')
            ?? allJobs.find(job => job.status === 'Queued')
            ?? allJobs.sort((a, b) => new Date(b.finishedAt ?? b.enqueuedAt ?? 0) - new Date(a.finishedAt ?? a.enqueuedAt ?? 0))[0];
    }

    function setText(selector, text) {
        const element = widget.querySelector(selector);
        if (element) {
            element.textContent = text;
        }
    }

    function render() {
        const job = selectVisibleJob();
        if (!job) {
            widget.classList.add('d-none');
            return;
        }

        widget.classList.remove('d-none', 'is-running', 'is-completed', 'is-failed');
        if (job.status === 'Running') {
            widget.classList.add('is-running');
        } else if (job.status === 'Completed' || job.isCompleted) {
            widget.classList.add('is-completed');
        } else if (job.status === 'Failed' || job.status === 'Cancelled' || job.isFailed) {
            widget.classList.add('is-failed');
        }

        const percent = Math.max(0, Math.min(100, Number(job.percent || 0)));
        const context = [];
        if (job.queuePosition) {
            context.push('Vị trí hàng đợi ' + job.queuePosition);
        }
        if (job.currentModel) {
            context.push(job.currentModel);
        }
        if (job.currentStrategy) {
            context.push(job.currentStrategy);
        }
        if (job.currentQuestion && job.totalQuestions > 0) {
            context.push('Câu ' + job.currentQuestion + '/' + job.totalQuestions);
        }
        if (job.queuedJobsForUser > 1) {
            context.push(job.queuedJobsForUser + ' job đang chờ');
        }

        const secondsSinceUpdate = Math.floor((Date.now() - job.receivedAt) / 1000);
        const elapsed = job.status === 'Running'
            ? job.elapsedSeconds + secondsSinceUpdate
            : job.elapsedSeconds;
        const remaining = job.estimatedRemainingSeconds === null || job.estimatedRemainingSeconds === undefined
            ? null
            : Math.max(0, Number(job.estimatedRemainingSeconds) - secondsSinceUpdate);

        setText('[data-ragas-job-status]', job.status === 'Queued' ? 'Đang chờ benchmark' : 'Đánh giá RAG');
        setText('[data-ragas-job-subject]', job.subjectName || ('Môn học ' + job.subjectId));
        setText('[data-ragas-job-message]', job.message || 'Đang chạy đánh giá...');
        setText('[data-ragas-job-context]', context.join(' · '));
        setText('[data-ragas-job-percent]', Math.round(percent) + '%');
        setText('[data-ragas-job-steps]', (job.completedSteps || 0) + '/' + (job.totalSteps || 0) + ' bước');
        setText('[data-ragas-job-elapsed]', formatDuration(elapsed));
        setText('[data-ragas-job-eta]', 'ETA: ' + (remaining === null ? 'Đang tính...' : formatDuration(remaining)));

        const bar = widget.querySelector('[data-ragas-job-bar]');
        if (bar) {
            bar.style.width = percent + '%';
        }
        const progress = widget.querySelector('.ragas-job-widget__bar');
        if (progress) {
            progress.setAttribute('aria-valuenow', String(Math.round(percent)));
        }

        const questionsLink = widget.querySelector('[data-ragas-job-open-questions]');
        if (questionsLink) {
            questionsLink.href = '/RagasEvaluation/Questions?subjectId=' + encodeURIComponent(job.subjectId);
        }
        const historyLink = widget.querySelector('[data-ragas-job-open-history]');
        if (historyLink) {
            historyLink.href = '/RagasEvaluation/History?subjectId=' + encodeURIComponent(job.subjectId);
            historyLink.classList.toggle('d-none', !(job.status === 'Completed' || job.isCompleted));
        }
    }

    async function ensureConnection() {
        if (connection && connection.state === signalR.HubConnectionState.Connected) {
            return connection;
        }

        if (!connection) {
            connection = new signalR.HubConnectionBuilder()
                .withUrl('/hubs/ragas-evaluation-progress')
                .withAutomaticReconnect()
                .build();

            connection.on('RagasEvaluationProgressUpdated', payload => {
                const job = normalize(payload);
                if (job.evaluationId) {
                    jobs.set(job.evaluationId, job);
                    render();
                }
            });

            connection.onreconnected(async () => {
                joined.clear();
                await loadCurrentJobs();
            });
        }

        if (connection.state === signalR.HubConnectionState.Disconnected) {
            await connection.start();
        }

        return connection;
    }

    async function joinJob(evaluationId) {
        if (!evaluationId || joined.has(evaluationId)) {
            return;
        }

        const hub = await ensureConnection();
        await hub.invoke('JoinEvaluation', evaluationId);
        joined.add(evaluationId);
    }

    async function loadCurrentJobs() {
        try {
            const response = await fetch(endpoints.current, {
                headers: { 'X-Requested-With': 'XMLHttpRequest' }
            });
            if (!response.ok) {
                return;
            }

            const payload = await response.json();
            const rawJobs = payload.jobs ?? payload.Jobs ?? [];
            for (const rawJob of rawJobs) {
                const job = normalize(rawJob);
                if (!job.evaluationId) {
                    continue;
                }

                jobs.set(job.evaluationId, job);
                if (!isTerminal(job)) {
                    await joinJob(job.evaluationId);
                }
            }

            render();
        } catch {
        }
    }

    async function enqueue(options) {
        const evaluationId = options.evaluationId || createEvaluationId();
        await joinJob(evaluationId);

        const response = await fetch(endpoints.run, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'RequestVerificationToken': options.antiforgeryToken || '',
                'X-Requested-With': 'XMLHttpRequest'
            },
            body: JSON.stringify({
                evaluationId,
                subjectId: options.subjectId,
                embeddingModels: options.embeddingModels || [],
                chunkingStrategies: options.chunkingStrategies || []
            })
        });

        const payload = await response.json().catch(() => ({}));
        if (!response.ok || payload.success === false) {
            throw new Error(payload.message || ('Không thể gửi yêu cầu đánh giá (HTTP ' + response.status + ').'));
        }

        const job = normalize(payload.status ?? payload.Status);
        if (job.evaluationId) {
            jobs.set(job.evaluationId, job);
            render();
        }

        return job;
    }

    window.ragasEvaluationJobs = {
        enqueue,
        refresh: loadCurrentJobs,
        formatDuration
    };

    ensureConnection()
        .then(loadCurrentJobs)
        .catch(() => {});

    clockTimer = setInterval(render, 1000);
    window.addEventListener('beforeunload', () => {
        if (clockTimer) {
            clearInterval(clockTimer);
        }
    });
})();
