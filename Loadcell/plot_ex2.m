% =========================================================================
% Academic Script: Load Cell Response & FFT Subplot Analysis
% Figure 1: Transfer Characteristics (Load Cell: Trial 2 vs Trial 3) [No Grand Mean]
% Figure 2: FFT Noise Spectrum Analysis ที่ใกล้เคียง 2, 4, 6, 8 kg -> Subplot 2x2
% =========================================================================
clearvars -except data; close all; clc;

% บังคับให้ MATLAB เปิดทุก Figure เป็นหน้าต่างลอยแยกอิสระ (ไม่ให้โดน Dock ฝังในจอ)
set(0, 'DefaultFigureWindowStyle', 'normal');

% -------------------------------------------------------------------------
% 1. โหลดข้อมูล
% -------------------------------------------------------------------------
matFile = 'data3.mat';
if ~exist(matFile, 'file') && exist('data.mat', 'file')
    matFile = 'data.mat';
end

if exist(matFile, 'file')
    S = load(matFile);
elseif exist('data', 'var') && isstruct(data)
    S = data;
else
    error('ไม่พบไฟล์ data3.mat หรือ data.mat ใน Workspace', matFile);
end

names = fieldnames(S);
rows = {};

% -------------------------------------------------------------------------
% 2. กรองเฉพาะ Trial 2 และ 3 พร้อมตัด Transient เอาช่วง Steady-State 60%
% -------------------------------------------------------------------------
for k = 1:numel(names)
    % กรองเฉพาะ Trial 2 และ 3 เท่านั้น (ลงท้ายด้วย _2 หรือ _3)
    token = regexp(names{k}, '^W(\d+)_([23])$', 'tokens', 'once');
    if isempty(token), continue; end
    
    rawLoad = str2double(token{1});
    weight_kg = rawLoad / 1000; % แปลงเป็นหน่วย kg (เช่น 2320 -> 2.32 kg)
    runNum = str2double(token{2});
    
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
        % กรณีไม่ได้ตั้งชื่อสัญญาณเป็น Vout ให้ดึงจาก Element 2 หรือ 1
        if isempty(ts) && numElements(val) >= 2
            ts = val.getElement(2).Values;
        elseif isempty(ts) && numElements(val) >= 1
            ts = val.getElement(1).Values;
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
    
    rows(end+1, :) = {string(names{k}), "LoadCell", weight_kg, ...
        runNum, numel(y), sum(mask), mean(y(mask)), std(y(mask)), ...
        {t(mask)}, {y(mask)}}; %#ok<SAGROW>
end

summary = cell2table(rows, 'VariableNames', {'Variable', 'Group', 'Position', ...
    'Run', 'TotalSamples', 'RetainedSamples', 'MeanVout', 'StdVout', 'TimeKeep', 'DataKeep'});
summary = sortrows(summary, {'Group', 'Position', 'Run'});

% =========================================================================
% Figure 1: Transfer Characteristics (แยกพล็อต Trial 2 และ 3 โดยไม่มี Grand Mean)
% =========================================================================
fig1 = figure('Name', 'Load Cell Characteristics (Trial 2 vs Trial 3)', 'Color', 'w', ...
              'WindowStyle', 'normal', 'MenuBar', 'figure', 'ToolBar', 'auto');

% ดึงข้อมูลแยกของแต่ละรอบการทดลอง
sub2 = summary(summary.Run == 2, :);
sub3 = summary(summary.Run == 3, :);

% พล็อตแต่ละรอบด้วยพิกัดตำแหน่งน้ำหนักจริงของตนเอง
plot(sub2.Position, sub2.MeanVout, 'o--', 'Color', [0.2 0.5 0.8], ...
    'LineWidth', 1.2, 'MarkerSize', 6);
hold on;
plot(sub3.Position, sub3.MeanVout, 's--', 'Color', [0.85 0.35 0.1], ...
    'LineWidth', 1.2, 'MarkerSize', 6);
hold off;

title('Single Point Load Cell Transfer Characteristics', 'FontSize', 15);
ylabel('Output Voltage (V)', 'FontSize', 13);
xlabel('Weight (kg)', 'FontSize', 13);

grid on; grid minor;
set(gca, 'LineWidth', 1.5, 'FontSize', 13);

xlim([0 10.5]);
xticks(0:1:10);
ylim([0 3.3]);
yticks(0:0.5:3.3);

legend({'Trial 2', 'Trial 3'}, 'Location', 'northwest', 'FontSize', 11);

% =========================================================================
% Figure 2: FFT Spectrum ใกล้เคียง 2, 4, 6, 8 kg -> Subplot 2x2
% =========================================================================
fig2 = figure('Name', 'Load Cell FFT Noise Spectrum (Subplot 2x2)', 'Color', 'w', ...
              'WindowStyle', 'normal', 'MenuBar', 'figure', 'ToolBar', 'auto');

targetWeights = [2, 4, 6, 8]; % ค่าน้ำหนักเป้าหมาย (kg)
fftRun = 2;                   % เลือกวิเคราะห์จากชุดข้อมูล Trial 2

% ค้นหาตำแหน่งน้ำหนักที่มีอยู่จริงใน Trial 2 ที่ใกล้เคียง 2, 4, 6, 8 kg มากที่สุด
targetPositions = zeros(size(targetWeights));
for idx = 1:numel(targetWeights)
    [~, minIdx] = min(abs(sub2.Position - targetWeights(idx)));
    targetPositions(idx) = sub2.Position(minIdx);
end

for idx = 1:numel(targetPositions)
    targetPos = targetPositions(idx);
    matchRow = sub2(sub2.Position == targetPos, :);
    
    subplot(2, 2, idx);
    if isempty(matchRow)
        title(sprintf('Weight %.3f kg: No Data', targetPos), 'FontSize', 14);
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
    
    title(sprintf('Single-Sided FFT at %.3f kg (~%d kg)', targetPos, targetWeights(idx)), 'FontSize', 13);
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