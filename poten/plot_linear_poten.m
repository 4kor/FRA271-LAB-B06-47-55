% =========================================================================
% Academic Script: Linear Potentiometer Response & FFT Subplot Analysis
% Updated: Force Undock (Floating Windows) + Complete Grid & Pan
% =========================================================================
clearvars -except data; close all; clc;

% บังคับให้ MATLAB เปิดทุก Figure เป็นหน้าต่างลอยแยกอิสระ (ไม่ให้โดน Dock ฝังในจอ)
set(0, 'DefaultFigureWindowStyle', 'normal');

% -------------------------------------------------------------------------
% 1. โหลดข้อมูล
% -------------------------------------------------------------------------
matFile = 'data.mat';
if exist(matFile, 'file')
    S = load(matFile);
elseif exist('data', 'var') && isstruct(data)
    S = data;
else
    error('ไม่พบไฟล์ %s หรือตัวแปร data ใน Workspace', matFile);
end

names = fieldnames(S);
rows = {};

% -------------------------------------------------------------------------
% 2. กรองและตัด Transient เอาช่วง Steady-State 60%
% -------------------------------------------------------------------------
for k = 1:numel(names)
    token = regexp(names{k}, '^(LA|LB)(\d+)_([12])$', 'tokens', 'once');
    if isempty(token), continue; end
    
    val = S.(names{k});
    ts = [];
    if isa(val, 'Simulink.SimulationData.Dataset')
        for j = 1:numElements(val)
            elem = getElement(val, j);
            paths = convertToCell(elem.BlockPath);
            if any(endsWith(string(paths), '/Vout')) || contains(elem.Name, 'Vout')
                ts = elem.Values;
                break;
            end
        end
    elseif isa(val, 'timeseries')
        ts = val;
    elseif isstruct(val) && isfield(val, 'time') && isfield(val, 'data')
        ts = timeseries(val.data, val.time);
    end
    
    if isempty(ts), continue; end
    t = double(ts.Time(:));
    y = double(ts.Data(:));
    if isempty(t) || isempty(y), continue; end
    
    t_start = t(1) + 0.2 * (t(end) - t(1));
    t_end   = t(1) + 0.8 * (t(end) - t(1));
    mask    = (t >= t_start) & (t <= t_end);
    if ~any(mask), continue; end
    
    rows(end+1, :) = {string(names{k}), string(token{1}), str2double(token{2}), ...
        str2double(token{3}), numel(y), sum(mask), mean(y(mask)), std(y(mask)), ...
        {t(mask)}, {y(mask)}}; %#ok<SAGROW>
end

summary = cell2table(rows, 'VariableNames', {'Variable', 'Group', 'Position', ...
    'Run', 'TotalSamples', 'RetainedSamples', 'MeanVout', 'StdVout', 'TimeKeep', 'DataKeep'});
summary = sortrows(summary, {'Group', 'Position', 'Run'});

% =========================================================================
% Figure 1: Transfer Characteristics (LA vs LB) -> Subplot 2x1
% =========================================================================
fig1 = figure('Name', 'Linear Potentiometer Characteristics', 'Color', 'w', ...
              'WindowStyle', 'normal', 'MenuBar', 'figure', 'ToolBar', 'auto');

targetGroups = ["LA", "LB"];
titles = ["Linear Potentiometer A (Audio/Logarithmic Taper)", ...
          "Linear Potentiometer B (Linear Taper)"];

for i = 1:2
    grpKey = targetGroups(i);
    grpData = summary(summary.Group == grpKey, :);
    pos = unique(grpData.Position);
    y1 = nan(size(pos));
    y2 = nan(size(pos));
    
    for p = 1:numel(pos)
        m1 = grpData.MeanVout(grpData.Position == pos(p) & grpData.Run == 1);
        m2 = grpData.MeanVout(grpData.Position == pos(p) & grpData.Run == 2);
        if ~isempty(m1), y1(p) = m1(1); end
        if ~isempty(m2), y2(p) = m2(1); end
    end
    ym = mean([y1, y2], 2, 'omitnan');
    
    subplot(2, 1, i);
    plot(pos, y1, 'o--', 'Color', [0.2 0.5 0.8], 'LineWidth', 1.2, 'MarkerSize', 6);
    hold on;
    plot(pos, y2, 's--', 'Color', [0.85 0.35 0.1], 'LineWidth', 1.2, 'MarkerSize', 6);
    plot(pos, ym, 'k.-', 'LineWidth', 2.0, 'MarkerSize', 16);
    hold off;
    
    title(titles(i), 'FontSize', 15);
    ylabel('Amplitude (V)', 'FontSize', 13);
    xlabel('Displacement (mm)', 'FontSize', 13);
    
    grid on; grid minor;
    set(gca, 'LineWidth', 1.5, 'FontSize', 13);
    
    xlim([0 60]);
    xticks(0:5:60);
    ylim([0 3.5]);
    yticks(0:0.5:3.5);
    
    legend({'Run 1', 'Run 2', 'Grand Mean'}, 'Location', 'northwest', 'FontSize', 11);
end

% =========================================================================
% Figure 2: FFT Spectrum ทั้ง 4 ตำแหน่ง -> Subplot 2x2
% =========================================================================
fig2 = figure('Name', 'FFT Noise Spectrum Analysis (Subplot 2x2)', 'Color', 'w', ...
              'WindowStyle', 'normal', 'MenuBar', 'figure', 'ToolBar', 'auto');

targetPositions = [15, 30, 45, 60];
fftGroup = "LA";

for idx = 1:numel(targetPositions)
    targetPos = targetPositions(idx);
    matchRow = summary(summary.Group == fftGroup & summary.Position == targetPos & summary.Run == 1, :);
    
    subplot(2, 2, idx);
    if isempty(matchRow)
        title(sprintf('Position %d mm: No Data', targetPos), 'FontSize', 14);
        continue;
    end
    
    t_seg = matchRow.TimeKeep{1};
    v_seg = matchRow.DataKeep{1};
    
    Fs = 1 / mean(diff(t_seg));
    N = length(v_seg);
    
    Y = fft(v_seg);
    P2 = abs(Y / N);
    P1 = P2(1:floor(N/2)+1);
    P1(2:end-1) = 2 * P1(2:end-1);
    f = Fs * (0:(floor(N/2))) / N;
    
    P1_dB = 20 * log10(P1 + eps);
    
    plot(f, P1_dB, 'Color', [0.85 0.15 0.15], 'LineWidth', 1.2);
    
    title(sprintf('Single-Sided Amplitude Spectrum (FFT) at %d mm', targetPos), 'FontSize', 13);
    ylabel('Magnitude (dBV)', 'FontSize', 11);
    xlabel('Frequency (Hz)', 'FontSize', 11);
    
    grid on; grid minor;
    set(gca, 'LineWidth', 1.3, 'FontSize', 10);
    
    % สเกลแกน X ทีละ 50 Hz
    xlim([0 500]);
    xticks(0:50:500);
    
    % สเกลแกน Y ทีละ 10 dBV
    ylim([-110 10]);
    yticks(-110:10:10);
    ytickformat('%d');
end

% =========================================================================
% Figure 2: FFT Spectrum ทั้ง 4 ตำแหน่ง -> Subplot 2x2
% =========================================================================
fig2 = figure('Name', 'FFT Noise Spectrum Analysis (Subplot 2x2)', 'Color', 'w', ...
    'WindowStyle', 'normal', 'MenuBar', 'figure', 'ToolBar', 'auto');

targetPositions = [15, 30, 45, 60];
fftGroup = "LB";

for idx = 1:numel(targetPositions)
    targetPos = targetPositions(idx);
    matchRow = summary(summary.Group == fftGroup & summary.Position == targetPos & summary.Run == 1, :);

    subplot(2, 2, idx);
    if isempty(matchRow)
        title(sprintf('Position %d mm: No Data', targetPos), 'FontSize', 14);
        continue;
    end

    t_seg = matchRow.TimeKeep{1};
    v_seg = matchRow.DataKeep{1};

    Fs = 1 / mean(diff(t_seg));
    N = length(v_seg);

    Y = fft(v_seg);
    P2 = abs(Y / N);
    P1 = P2(1:floor(N/2)+1);
    P1(2:end-1) = 2 * P1(2:end-1);
    f = Fs * (0:(floor(N/2))) / N;

    P1_dB = 20 * log10(P1 + eps);

    plot(f, P1_dB, 'Color', [0.85 0.15 0.15], 'LineWidth', 1.2);

    title(sprintf('Single-Sided Amplitude Spectrum (FFT) at %d mm', targetPos), 'FontSize', 13);
    ylabel('Magnitude (dBV)', 'FontSize', 11);
    xlabel('Frequency (Hz)', 'FontSize', 11);

    grid on; grid minor;
    set(gca, 'LineWidth', 1.3, 'FontSize', 10);

    % สเกลแกน X ทีละ 50 Hz
    xlim([0 500]);
    xticks(0:50:500);

    % สเกลแกน Y ทีละ 10 dBV
    ylim([-110 10]);
    yticks(-110:10:10);
    ytickformat('%d');
end