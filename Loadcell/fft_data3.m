clear;
clc;
close all;
dataFolder = 'C:\Users\Admin\Desktop\RMX\Lab\Load cell';
S = load(fullfile(dataFolder, 'data3.mat'));
names = fieldnames(S);
selectedTrials = [2 3];
trimFraction = 0.20;
spectra = [];
source = strings(0,1);
trial = [];
peakHz = [];
peakAmplitude = [];
sampleRates = [];
for k = 1:numel(names)
    token = regexp(names{k}, '^W(\d+)_(\d+)$', 'tokens', 'once');
    if isempty(token) || ~ismember(str2double(token{2}), selectedTrials)
        continue;
    end
    ts = S.(names{k}).getElement(2).Values;
    t = double(ts.Time(:));
    x = double(ts.Data(:));
    dt = median(diff(t));
    assert(all(isfinite(x)) && all(isfinite(t)), 'Nonfinite samples: %s', names{k});
    assert(dt > 0 && max(abs(diff(t)-dt)) < 1e-6*dt, ...
        'FFT requires uniformly sampled data: %s', names{k});
    Fs = 1/dt;
    keep = floor(trimFraction*numel(x))+1:ceil((1-trimFraction)*numel(x));
    x = x(keep);
    x = x - mean(x); % Remove DC only; preserve slow fluctuations.
    N = numel(x);
    win = 0.5 - 0.5*cos(2*pi*(0:N-1)'/(N-1)); % Hann window
    Y = fft(x.*win);
    nFreq = floor(N/2)+1;
    amplitude = abs(Y(1:nFreq))/sum(win);
    powerDensity = abs(Y(1:nFreq)).^2/(Fs*sum(win.^2));
    if rem(N,2)==0
        doubleBins = 2:nFreq-1;
    else
        doubleBins = 2:nFreq;
    end
    amplitude(doubleBins) = 2*amplitude(doubleBins);
    powerDensity(doubleBins) = 2*powerDensity(doubleBins);
    f = (0:nFreq-1)'*Fs/N;
    if isempty(spectra)
        frequencyHz = f;
    else
        assert(numel(f)==numel(frequencyHz) && max(abs(f-frequencyHz))<1e-6, ...
            'Recording frequency grids differ.');
    end
    spectra(:,end+1) = powerDensity;
    [pk,j] = max(amplitude(2:end));
    source(end+1,1) = string(names{k});
    trial(end+1,1) = str2double(token{2});
    peakHz(end+1,1) = f(j+1);
    peakAmplitude(end+1,1) = pk;
    sampleRates(end+1,1) = Fs;
end
T = table(source,trial,sampleRates,peakHz,peakAmplitude, ...
    'VariableNames',{'Source','Trial','SampleRate_Hz','DominantFrequency_Hz','PeakAmplitude_V'});
writetable(T,fullfile(dataFolder,'data3_trials23_fft_peaks.csv'));
meanPSD = mean(spectra,2); % Average powers, not complex FFT coefficients.
writetable(table(frequencyHz,meanPSD),fullfile(dataFolder,'data3_trials23_fft_psd.csv'));
fig = figure('Color','w','Position',[100 100 1200 800]);
layout = tiledlayout(2,1,'Padding','compact');
limits = [0 max(frequencyHz); 0 100];
for panel = 1:2
    ax = nexttile;
    hold(ax,'on');
    for j=1:size(spectra,2)
        plot(frequencyHz,10*log10(max(spectra(:,j),realmin)), ...
            'Color',[0.8 0.8 0.8],'HandleVisibility','off');
    end
    for r=selectedTrials
        plot(frequencyHz,10*log10(max(mean(spectra(:,trial==r),2),realmin)), ...
            'LineWidth',1.4,'DisplayName',sprintf('Trial %d mean PSD',r));
    end
    xlim(limits(panel,:));
    grid on;
    xlabel('Frequency (Hz)'); ylabel('PSD (dB re 1 V^2/Hz)');
    title('Middle 60%: mean removed, Hann-window FFT');
    legend('Location','best','Color','w','TextColor','k');
    set(ax,'Color','w','XColor','k','YColor','k');
    ax.Title.Color='k';
end
exportgraphics(fig,fullfile(dataFolder,'data3_trials23_fft.png'),'Resolution',160);
fprintf('Recordings=%d; Fs=%.6f Hz; segment=%d samples; resolution=%.6f Hz\n', ...
    height(T),sampleRates(1),N,frequencyHz(2));
disp(T);
edges=[0 1 5 10 20 40 60 100 200 501];
totalPower=sum(meanPSD(2:end));
for j=1:numel(edges)-1
    mask=frequencyHz>0 & frequencyHz>=edges(j) & frequencyHz<edges(j+1);
    fprintf('Band %g-%g Hz: %.3f percent of non-DC power\n', ...
        edges(j),min(edges(j+1),sampleRates(1)/2),100*sum(meanPSD(mask))/totalPower);
end
[~,order]=sort(meanPSD(2:end),'descend');
disp(table(frequencyHz(order(1:10)+1),meanPSD(order(1:10)+1), ...
    'VariableNames',{'TopFrequency_Hz','PSD_V2_per_Hz'}));
