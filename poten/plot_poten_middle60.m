% Plot Vout using the middle 60% of each recording in data.mat.
% Position values come from variable names; physical units are unspecified.
base = fileparts(mfilename('fullpath'));
S = load(fullfile(base,'data.mat'));
outputDir = fullfile(base,'plots_middle60');
if ~exist(outputDir,'dir'), mkdir(outputDir); end
names = fieldnames(S);
rows = {};
for k = 1:numel(names)
    token = regexp(names{k},'^(LA|LB|RA|RB|RC)(\d+)_([12])$','tokens','once');
    if isempty(token), continue; end
    value = S.(names{k});
    if isa(value,'Simulink.SimulationData.Dataset')
        ts = [];
        for j = 1:numElements(value)
            signal = getElement(value,j);
            paths = convertToCell(signal.BlockPath);
            if any(endsWith(string(paths),'/Vout'))
                ts = signal.Values;
                break
            end
        end
        assert(~isempty(ts),'Vout not found in %s',names{k});
    else
        assert(isa(value,'timeseries') && contains(value.Name,'Vout'), ...
            'Unexpected signal type in %s',names{k});
        ts = value;
    end
    t = double(ts.Time(:));
    y = double(ts.Data(:));
    assert(numel(t)==numel(y) && all(diff(t)>=0));
    lower = t(1)+0.2*(t(end)-t(1));
    upper = t(1)+0.8*(t(end)-t(1));
    keep = t>=lower & t<=upper;
    assert(any(keep) && all(isfinite(y(keep))),'Invalid retained data');
    rows(end+1,:) = {string(names{k}),string(token{1}),str2double(token{2}), ...
        str2double(token{3}),numel(y),sum(keep),lower,upper, ...
        mean(y(keep)),std(y(keep))}; %#ok<SAGROW>
end
summary = cell2table(rows,'VariableNames',{'Variable','Group','Position', ...
    'Run','TotalSamples','RetainedSamples','StartTime','EndTime','MeanVout','StdVout'});
summary = sortrows(summary,{'Group','Position','Run'});
assert(height(summary)==178,'Expected 178 recordings');
groups = ["LA","LB","RA","RB","RC"];
titles = ["LA - Linear potentiometer A","LB - Linear potentiometer B", ...
    "RA - Rotary potentiometer A","RB - Rotary potentiometer B", ...
    "RC - Rotary potentiometer C"];
overview = figure('Visible','off','Theme','light','Color','w','Position',[50 50 1500 900]);
layout = tiledlayout(overview,2,3,'TileSpacing','compact','Padding','compact');
title(layout,'Potentiometer response | middle 60% of each recording','FontSize',19);
subtitle(layout,'Vout mean per run; position values from dataset names (units unspecified)');
means = struct;
for g = 1:numel(groups)
    a = summary(summary.Group==groups(g) & summary.Run==1,:);
    b = summary(summary.Group==groups(g) & summary.Run==2,:);
    assert(isequal(a.Position,b.Position),'Unpaired positions');
    averaged = (a.MeanVout+b.MeanVout)/2;
    means.(groups(g)) = table(a.Position,a.MeanVout,b.MeanVout,averaged, ...
        'VariableNames',{'Position','Run1','Run2','MeanBothRuns'});
    ax = nexttile(layout);
    drawCurve(ax,a.Position,a.MeanVout,b.MeanVout,averaged,titles(g));
    f = figure('Visible','off','Theme','light','Color','w','Position',[50 50 1100 720]);
    drawCurve(axes(f),a.Position,a.MeanVout,b.MeanVout,averaged,titles(g));
    subtitle('Mean of middle 60% (trim 20% from each end)');
    exportgraphics(f,fullfile(outputDir,groups(g)+"_middle60.png"),'Resolution',200);
    savefig(f,fullfile(outputDir,groups(g)+"_middle60.fig"));
    close(f);
end
exportgraphics(overview,fullfile(outputDir,'potentiometers_overview.png'),'Resolution',180);
savefig(overview,fullfile(outputDir,'potentiometers_overview.fig'));
close(overview);
save(fullfile(outputDir,'middle60_results.mat'),'summary','means');
fprintf('Processed %d recordings. Retained samples: %d to %d. Time range: %.6g to %.6g.\n', ...
    height(summary),min(summary.RetainedSamples),max(summary.RetainedSamples), ...
    min(summary.StartTime),max(summary.EndTime));
function drawCurve(ax,x,y1,y2,ym,label)
    plot(ax,x,y1,'o--','Color',[0.2 0.5 0.8],'LineWidth',1.2,'MarkerSize',4);
    hold(ax,'on');
    plot(ax,x,y2,'s--','Color',[0.9 0.45 0.15],'LineWidth',1.2,'MarkerSize',4);
    plot(ax,x,ym,'k.-','LineWidth',2,'MarkerSize',13);
    grid(ax,'on');
    xlabel(ax,'Position value in dataset name'); ylabel(ax,'Mean Vout (V)');
    title(ax,label,'FontSize',14);
    legend(ax,{'Run 1','Run 2','Mean of both runs'},'Location','best');
    set(ax,'FontSize',11);
end
