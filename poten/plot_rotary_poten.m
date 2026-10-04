% =========================================================================
% Academic Script: Rotary Potentiometer Response & FFT Subplot Analysis
% Figure 1: Transfer Characteristics (RA, RB, RC) -> Subplot 3x1
% Figure 2: FFT Noise Spectrum RA (20, 40, 60, 80 deg) -> Subplot 2x2
% Figure 3: FFT Noise Spectrum RB (20, 40, 60, 80 deg) -> Subplot 2x2
% Figure 4: FFT Noise Spectrum RC (20, 40, 60, 80 deg) -> Subplot 2x2
% =========================================================================
clearvars -except data; close all; clc;

% บังคับให้ MATLAB เปิดทุก Figure เป็นหน้าต่างลอยแยกอิสระ
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
    token = regexp(names{k}, '^(RA|RB|RC)(\d+)_([12])$', 'tokens', 'once');
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
% Figure 1: Transfer Characteristics (RA, RB, RC) -> Subplot 3x1
% =========================================================================
fig1 = figure('Name', 'Rotary Potentiometer Characteristics', 'Color', 'w', ...
              'WindowStyle', 'normal', 'MenuBar', 'figure', 'ToolBar', 'auto');

targetGroups = ["RA", "RB", "RC"];
titles = ["Rotary Potentiometer A (Audio/Logarithmic Taper)", ...
          "Rotary Potentiometer B (Linear Taper)", ...
          "Rotary Potentiometer C (Reverse Logarithmic Taper)"];

for i = 1:3
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
    
    subplot(3, 1, i);
    plot(pos, y1, 'o--', 'Color', [0.2 0.5 0.8], 'LineWidth', 1.2, 'MarkerSize', 6);
    hold on;
    plot(pos, y2, 's--', 'Color', [0.85 0.35 0.1], 'LineWidth', 1.2, 'MarkerSize', 6);
    plot(pos, ym, 'k.-', 'LineWidth', 2.0, 'MarkerSize', 16);
    hold off;
    
    title(titles(i), 'FontSize', 13);
    ylabel('Amplitude (V)', 'FontSize', 11);
    xlabel('Angular Position (deg)', 'FontSize', 11);
    
    grid on; grid minor;
    set(gca, 'LineWidth', 1.3, 'FontSize', 10);
    
    if ~isempty(pos)
        xlim([min(pos) max(pos)]);
        xticks(pos);
    end
    ylim([0 3.5]);
    yticks(0:0.5:3.5);
    
    legend({'Run 1', 'Run 2', 'Grand Mean'}, 'Location', 'northwest', 'FontSize', 9);
end

% กำหนดตำแหน่งมุม 4 จุดสำหรับวิเคราะห์ FFT
targetPositions = [20, 40, 60, 80];

% =========================================================================
% Figure 2: FFT Spectrum RA -> Subplot 2x2
% =========================================================================
fig2 = figure('Name', 'FFT Noise Spectrum RA (Subplot 2x2)', 'Color', 'w', ...
              'WindowStyle', 'normal', 'MenuBar', 'figure', 'ToolBar', 'auto');
fftGroup = "RA";
for idx = 1:numel(targetPositions)
    targetPos = targetPositions(idx);
    matchRow = summary(summary.Group == fftGroup & summary.Position == targetPos & summary.Run == 1, :);
    
    subplot(2, 2, idx);
    if isempty(matchRow)
        title(sprintf('Angle %d deg: No Data', targetPos), 'FontSize', 13);
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
    
    title(sprintf('Single-Sided Amplitude Spectrum (FFT) at %d deg', targetPos), 'FontSize', 13);
    ylabel('Magnitude (dBV)', 'FontSize', 11);
    xlabel('Frequency (Hz)', 'FontSize', 11);
    
    grid on; grid minor;
    set(gca, 'LineWidth', 1.3, 'FontSize', 10);
    
    xlim([0 500]);
    xticks(0:50:500);
    ylim([-110 10]);
    yticks(-110:10:10);
    ytickformat('%d');
end

% =========================================================================
% Figure 3: FFT Spectrum RB -> Subplot 2x2
% =========================================================================
fig3 = figure('Name', 'FFT Noise Spectrum RB (Subplot 2x2)', 'Color', 'w', ...
              'WindowStyle', 'normal', 'MenuBar', 'figure', 'ToolBar', 'auto');
fftGroup = "RB";
for idx = 1:numel(targetPositions)
    targetPos = targetPositions(idx);
    matchRow = summary(summary.Group == fftGroup & summary.Position == targetPos & summary.Run == 1, :);
    
    subplot(2, 2, idx);
    if isempty(matchRow)
        title(sprintf('Angle %d deg: No Data', targetPos), 'FontSize', 13);
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
    
    title(sprintf('Single-Sided Amplitude Spectrum (FFT) at %d deg', targetPos), 'FontSize', 13);
    ylabel('Magnitude (dBV)', 'FontSize', 11);
    xlabel('Frequency (Hz)', 'FontSize', 11);
    
    grid on; grid minor;
    set(gca, 'LineWidth', 1.3, 'FontSize', 10);
    
    xlim([0 500]);
    xticks(0:50:500);
    ylim([-110 10]);
    yticks(-110:10:10);
    ytickformat('%d');
end

% =========================================================================
% Figure 4: FFT Spectrum RC -> Subplot 2x2
% =========================================================================
fig4 = figure('Name', 'FFT Noise Spectrum RC (Subplot 2x2)', 'Color', 'w', ...
              'WindowStyle', 'normal', 'MenuBar', 'figure', 'ToolBar', 'auto');
fftGroup = "RC";
for idx = 1:numel(targetPositions)
    targetPos = targetPositions(idx);
    matchRow = summary(summary.Group == fftGroup & summary.Position == targetPos & summary.Run == 1, :);
    
    subplot(2, 2, idx);
    if isempty(matchRow)
        title(sprintf('Angle %d deg: No Data', targetPos), 'FontSize', 13);
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
    
    title(sprintf('Single-Sided Amplitude Spectrum (FFT) at %d deg', targetPos), 'FontSize', 13);
    ylabel('Magnitude (dBV)', 'FontSize', 11);
    xlabel('Frequency (Hz)', 'FontSize', 11);
    
    grid on; grid minor;
    set(gca, 'LineWidth', 1.3, 'FontSize', 10);
    
    xlim([0 500]);
    xticks(0:50:500);
    ylim([-110 10]);
    yticks(-110:10:10);
    ytickformat('%d');
end