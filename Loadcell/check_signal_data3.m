clear; clc; close all;
folder = 'C:\Users\Admin\Desktop\RMX\Lab\Load cell';
S = load(fullfile(folder,'data3.mat'));
names = fieldnames(S);
source = strings(0,1); trial=[]; weight=[]; meanV=[]; rmsAC=[];
firstMean=[]; lastMean=[]; slowRMS=[]; bandRMS=[]; otherRMS=[];
examples={'W00000_2','W04830_2','W10267_2'};
fig=figure('Color','w','Position',[100 100 1250 850]);
tl=tiledlayout(2,2,'Padding','compact');
ax1=nexttile; hold on; ax2=nexttile; hold on;
ax3=nexttile; hold on; ax4=nexttile; hold on;
colors=[0 0.35 0.7;0.85 0.3 0.05;0.1 0.55 0.25];
for k=1:numel(names)
    tok=regexp(names{k},'^W(\d+)_([23])$','tokens','once');
    if isempty(tok), continue; end
    ts=S.(names{k}).getElement(2).Values;
    t=double(ts.Time(:)); x=double(ts.Data(:));
    Fs=1/median(diff(t));
    keep=floor(.2*numel(x))+1:ceil(.8*numel(x));
    t=t(keep); x=x(keep); n=numel(x); mu=mean(x); z=x-mu;
    % Parseval power accounting; no window, so powers sum to exact AC RMS^2.
    Z=fft(z); f=(0:n-1)'*Fs/n; folded=min(f,Fs-f);
    P=abs(Z).^2/n^2;
    source(end+1,1)=string(names{k}); trial(end+1,1)=str2double(tok{2});
    weight(end+1,1)=str2double(tok{1})/10; meanV(end+1,1)=mu;
    rmsAC(end+1,1)=sqrt(mean(z.^2));
    q=floor(n/3); firstMean(end+1,1)=mean(x(1:q)); lastMean(end+1,1)=mean(x(end-q+1:end));
    slowRMS(end+1,1)=sqrt(sum(P(folded>0 & folded<1)));
    bandRMS(end+1,1)=sqrt(sum(P(folded>=5 & folded<10)));
    otherRMS(end+1,1)=sqrt(sum(P(folded>=10)));
    j=find(strcmp(names{k},examples));
    if ~isempty(j)
        label=sprintf('%.1f g (Trial 2)',weight(end));
        plot(ax2,t,x,'Color',colors(j,:),'DisplayName',label);
        plot(ax3,t,1000*z,'Color',colors(j,:),'DisplayName',label);
        win=.5-.5*cos(2*pi*(0:n-1)'/(n-1)); Y=fft(z.*win);
        nf=floor(n/2)+1; ps=abs(Y(1:nf)).^2/(Fs*sum(win.^2));
        ps(2:end)=2*ps(2:end); % These recordings have odd segment length.
        plot(ax4,(0:nf-1)'*Fs/n,10*log10(max(ps,realmin)), ...
            'Color',colors(j,:),'DisplayName',label);
    end
end
for r=[2 3]
    use=trial==r; [w,idx]=sort(weight(use)); v=meanV(use);
    plot(ax1,w,v(idx),'-o','DisplayName',sprintf('Trial %d',r));
end
title(ax1,'Mean voltage changes with reference mass'); xlabel(ax1,'Reference mass (g)'); ylabel(ax1,'Mean voltage (V)');
title(ax2,'Raw voltage: three separate constant-load recordings'); xlabel(ax2,'Time (s)'); ylabel(ax2,'Voltage (V)');
title(ax3,'Same recordings, each mean removed'); xlabel(ax3,'Time (s)'); ylabel(ax3,'Deviation from own mean (mV)');
title(ax4,'Separate spectra: not averaged across masses'); xlabel(ax4,'Frequency (Hz)'); ylabel(ax4,'PSD (dB re 1 V^2/Hz)'); xlim(ax4,[0 40]);
for ax=[ax1 ax2 ax3 ax4]
    grid(ax,'on'); set(ax,'Color','w','XColor','k','YColor','k'); ax.Title.Color='k';
    legend(ax,'Location','best','Color','w','TextColor','k');
end
exportgraphics(fig,fullfile(folder,'data3_signal_evidence.png'),'Resolution',160);
T=table(source,trial,weight,meanV,rmsAC,firstMean,lastMean,slowRMS,bandRMS,otherRMS);
writetable(T,fullfile(folder,'data3_signal_evidence.csv'));
R=corrcoef(weight,meanV);
fprintf('Correlation reference mass vs mean voltage: %.9f\n',R(1,2));
disp(T(ismember(source,string(examples)) | source=="W10267_3",:));
fprintf('Median AC RMS = %.6f mV; min = %.6f; max = %.6f\n',1000*median(rmsAC),1000*min(rmsAC),1000*max(rmsAC));
fprintf('First-to-last 2s mean change at maximum trial 3: %.6f mV\n', ...
    1000*(lastMean(source=="W10267_3")-firstMean(source=="W10267_3")));
