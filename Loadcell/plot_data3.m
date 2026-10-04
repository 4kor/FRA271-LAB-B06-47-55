clear;
clc;
close all;

% ตัดข้อมูลด้านหน้าและด้านท้ายข้างละ 20%
trimFraction = 0.20;
selectedTrials = [2 3];

% ระบุโฟลเดอร์จริง เพราะ MATLAB Editor อาจรันไฟล์จากโฟลเดอร์ Temp
dataFolder = 'C:\Users\Admin\Desktop\RMX\Lab\Load cell';
dataFile = fullfile(dataFolder, 'data3.mat');
S = load(dataFile);

variableNames = fieldnames(S);
weight_g = [];
averageVoltage_V = [];
trial = [];
sourceName = strings(0, 1);

for i = 1:numel(variableNames)
    name = variableNames{i};
    token = regexp(name, '^W(\d+)_(\d+)$', 'tokens', 'once');

    if isempty(token)
        continue;
    end

    trialNumber = str2double(token{2});
    if ~ismember(trialNumber, selectedTrials)
        continue;
    end
    loadNumber = str2double(token{1});

    % รอบที่ 1 บันทึกชื่อเป็นจำนวนเต็ม เช่น W0050_1 = 50 g
    % รอบที่ 2 และ 3 บันทึกทศนิยมหนึ่งตำแหน่ง เช่น W00305_2 = 30.5 g
    if trialNumber == 1
        currentWeight = loadNumber;
    else
        currentWeight = loadNumber / 10;
    end

    dataset = S.(name);
    voltageSignal = dataset.getElement(2).Values;
    voltage = squeeze(voltageSignal.Data);
    voltage = voltage(:);

    numberOfSamples = numel(voltage);
    firstSample = floor(trimFraction * numberOfSamples) + 1;
    lastSample = ceil((1 - trimFraction) * numberOfSamples);
    middleVoltage = voltage(firstSample:lastSample);

    weight_g(end + 1, 1) = currentWeight;
    averageVoltage_V(end + 1, 1) = mean(middleVoltage, 'omitnan');
    trial(end + 1, 1) = trialNumber;
    sourceName(end + 1, 1) = string(name);
end

result = table(weight_g, averageVoltage_V, trial, sourceName, ...
    'VariableNames', {'Weight_g', 'AverageVoltage_V', 'Trial', 'Source'});
result = sortrows(result, {'Trial', 'Weight_g'});

% สมการแปลงแรงดันเป็นกรัม โดยใช้เฉพาะรอบที่เลือก
% น้ำหนักอ้างอิงยังอิงการถอดชื่อชุดข้อมูลข้างต้น
p = polyfit(result.AverageVoltage_V, result.Weight_g, 1);
gain_g_per_V = p(1);
bias_g = p(2);
fitError_g = polyval(p, result.AverageVoltage_V) - result.Weight_g;
fitRMSE_g = sqrt(mean(fitError_g.^2));
fitMaxAbsError_g = max(abs(fitError_g));

figure('Color', 'w');
hold on;

colors = lines(3);
for trialNumber = selectedTrials
    useRow = result.Trial == trialNumber;
    plot(result.Weight_g(useRow), result.AverageVoltage_V(useRow), ...
        '-o', ...
        'Color', colors(trialNumber, :), ...
        'LineWidth', 1.5, ...
        'MarkerSize', 5, ...
        'DisplayName', sprintf('Trial %d', trialNumber));
end

grid on;
box on;
xlabel('Weight (g)');
ylabel('Average voltage (V)');
title('Load Cell: Trials 2 and 3 (Middle 60% Average)');
legend('Location', 'best');
ax = gca;
ax.Color = 'w';
ax.XColor = 'k';
ax.YColor = 'k';
ax.GridColor = [0.75 0.75 0.75];
ax.Title.Color = 'k';
hold off;

outputImage = fullfile(dataFolder, 'data3_trials23_average_middle.png');
outputTable = fullfile(dataFolder, 'data3_trials23_average_middle.csv');
exportgraphics(gcf, outputImage, 'Resolution', 200);
writetable(result, outputTable);

disp(result);
fprintf('\nWeight(g) = %.9f * Voltage(V) + %.9f\n', gain_g_per_V, bias_g);
fprintf('Fit RMSE = %.6f g; max absolute fit error = %.6f g\n', ...
    fitRMSE_g, fitMaxAbsError_g);
fprintf('\nSaved graph: %s\n', outputImage);
fprintf('Saved averages: %s\n', outputTable);
