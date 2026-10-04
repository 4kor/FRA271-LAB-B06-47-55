% =========================================================================
% Academic Script: Export Load Cell Representative Values to Excel
% Export Steady-State Mean (60%), Std, and Reference Weights (Trial 2 & 3)
% =========================================================================
clearvars -except data; clc;

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
    token = regexp(names{k}, '^W(\d+)_([23])$', 'tokens', 'once');
    if isempty(token), continue; end

    rawLoad = str2double(token{1});
    weight_kg = rawLoad / 1000; % แปลงเป็นหน่วย kg
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

    % ตัด Transient หัวท้ายข้างละ 20% เอาช่วงคงที่ Steady-State 60%
    t_start = t(1) + 0.2 * (t(end) - t(1));
    t_end   = t(1) + 0.8 * (t(end) - t(1));
    mask    = (t >= t_start) & (t <= t_end);
    if ~any(mask), continue; end

    % เก็บค่าตัวแทน: ชื่อตัวแปร, Trial, น้ำหนัก (kg), แรงดันเฉลี่ย (V), SD (V), จำนวนจุด
    rows(end+1, :) = {string(names{k}), runNum, weight_kg, ...
        mean(y(mask)), std(y(mask)), sum(mask)}; %#ok<SAGROW>
end

% -------------------------------------------------------------------------
% 3. สร้าง Table และแยกตารางแต่ละ Trial
% -------------------------------------------------------------------------
summaryTable = cell2table(rows, 'VariableNames', ...
    {'VariableName', 'Trial', 'Weight_kg', 'Mean_Vout_V', 'Std_Vout_V', 'SampleCount'});
summaryTable = sortrows(summaryTable, {'Trial', 'Weight_kg'});

% แยกข้อมูลเฉพาะของ Trial 2 และ Trial 3
T2 = summaryTable(summaryTable.Trial == 2, {'Weight_kg', 'Mean_Vout_V', 'Std_Vout_V', 'SampleCount'});
T3 = summaryTable(summaryTable.Trial == 3, {'Weight_kg', 'Mean_Vout_V', 'Std_Vout_V', 'SampleCount'});

% -------------------------------------------------------------------------
% 4. บันทึกออกเป็นไฟล์ Excel (.xlsx)
% -------------------------------------------------------------------------
excelFileName = 'LoadCell_Representative_Values.xlsx';

% เขียนแยกลงในแต่ละ Sheet
writetable(summaryTable, excelFileName, 'Sheet', 'All_Trials');
writetable(T2, excelFileName, 'Sheet', 'Trial_2');
writetable(T3, excelFileName, 'Sheet', 'Trial_3');

fprintf('ส่งออกไฟล์ Excel สำเร็จ: %s\n', excelFileName);
disp('ตัวอย่างข้อมูล Trial 2:');
disp(head(T2));