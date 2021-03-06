
function [att,rel] = VPU(att_peak,rel_peak,att_valley,rel_valley)


path = '../../Data/';
fsDSP = 20833;
blkSize = 32;


close all;

blkFreq = floor(fsDSP / blkSize);
winLength = round(0.010*blkFreq); %#ok<NASGU>

%load the signals
[Mix(1).data,fs] = audioread(strcat(path,'Voice+Cantine.wav'));
[Mix(2).data,~] = audioread(strcat(path,'Cantine.wav'));
[Mix(3).data,~] = audioread(strcat(path,'Silence.wav'));



for idx = 1:3
    Mix(idx).data = resample(Mix(idx).data,fsDSP,fs,50);
    for i = 1:length(Mix(idx).data)/blkSize - 1
        Mix(idx).blkmean(i,1) = mean(Mix(idx).data((i-1)*blkSize + 1 : i*blkSize,:));
    end
    Mix(idx).max = max(Mix(idx).blkmean);
    Mix(idx).rms = rms(Mix(idx).blkmean);
    Mix(idx).spec = 20*log10(abs(spectrogram(Mix(idx).data,200,100,512,fsDSP)));
    Mix(idx).t = linspace(0,floor(length(Mix(idx).blkmean))/blkFreq,floor(length(Mix(idx).blkmean)));
end


f = linspace(0,fsDSP/2,512/2 +1);


figure;

scale = [-70 10];

subplot(2,3,1);
plot(Mix(1).t,Mix(1).blkmean);
set(gca,'YLim',[-0.6 0.6],'XLim',[0 Mix(1).t(end)]);
title('Own Voice in Cantine');
ylabel('Amplitude');

subplot(2,3,2);
plot(Mix(2).t,Mix(2).blkmean);
set(gca,'YLim',[-0.6 0.6],'XLim',[0 Mix(2).t(end)]);
title('Cantine');

subplot(2,3,3);
plot(Mix(3).t,Mix(3).blkmean);
set(gca,'YLim',[-0.6 0.6],'XLim',[0 Mix(3).t(end)]);
title('Silence');


subplot(2,3,4);
imagesc(Mix(1).t,f,Mix(1).spec,scale);
set(gca, 'YDir','normal');
xlabel('Time (sec)');
ylabel('Freq (Hz)');

subplot(2,3,5);
imagesc(Mix(2).t,f,Mix(2).spec,scale);
set(gca, 'YDir','normal');
xlabel('Time (sec)');

subplot(2,3,6);
imagesc(Mix(3).t,f,Mix(3).spec,scale); colorbar;
set(gca, 'YDir','normal');
xlabel('Time (sec)');

colormap('parula')


% amplitude distributions
figure;
histogram(Mix(1).blkmean);
hold on;
histogram(Mix(2).blkmean);


% simple threshold criteria
figure;
plot(20*log10(abs(Mix(2).blkmean)))
hold on; plot(20*log10(abs(Mix(1).blkmean)))
hold on; plot(20*log10(abs(Mix(3).blkmean)))


Mix(1).rms = 20*log10(rms(Mix(1).blkmean));
Mix(2).rms = 20*log10(rms(Mix(2).blkmean));
Mix(3).rms = 20*log10(rms(Mix(3).blkmean));



%make peak & valley detection
d = 1e-4*ones(length(Mix(1).blkmean),3);
v = 1e-4*ones(length(Mix(1).blkmean),3);

out = zeros(size(Mix(1).blkmean));

for l = 1:3
    for idx = 2 : blkFreq*53  %     length(Mix(1).blkmean)
        
        d(idx,l) =  Peak(Mix(l).blkmean(idx,1), d(idx - 1,l), att_peak, rel_peak);
        v(idx,l) =  Valley(Mix(l).blkmean(idx,1), v(idx - 1,l), att_valley, rel_valley);
        out(idx,l) = detect(d(idx,l),v(idx,l),55);
        
    end
    out(:,l) = filter(1/10*ones(10,1),1,out(:,l));    
end

% moving average filter 



range = 100:35000;%6000:10000;

bla = linspace(0,53,length(range));

figure;
plot(20*log10(abs(Mix(1).blkmean)),'color',[0.8 0.8 0.8]);
hold on; plot(20*log10(d),'r');
hold on; plot(20*log10(v),'b');

figure;
subplot(2,1,1)
plot(bla,20*log10(abs(Mix(1).blkmean(range,1))),'color',[0.6 0.6 0.6]);
hold on; plot(bla,20*log10(d(range,1)),'r');
hold on; plot(bla,20*log10(v(range,1)),'b');


subplot(2,1,2)
plot(bla,out(range,1),'b');
set(gca,'YLim',[-0.1 1.3]);
xlabel('Time (sec)');


figure;
subplot(2,2,1)
plot(bla,20*log10(abs(Mix(1).blkmean(range,1))),'color',[0.6 0.6 0.6]);
hold on; plot(bla,20*log10(d(range,1)),'r');
hold on; plot(bla,20*log10(v(range,1)),'b');
set(gca,'YLim',[-140 0],'XTick',[]);
title('Canteen plus own-voice');
ylabel('Amplitude re. 1 (dB)');


subplot(2,2,3)
plot(bla,out(range,1),'b');
set(gca,'YLim',[-0.1 1.3]);
ylabel('Probability of speech');
xlabel('Time (sec)');


subplot(2,2,2)
plot(bla,20*log10(abs(Mix(2).blkmean(range,1))),'color',[0.6 0.6 0.6]);
hold on; plot(bla,20*log10(d(range,2)),'r');
hold on; plot(bla,20*log10(v(range,2)),'b');
set(gca,'YLim',[-140 0],'XTick',[]);
title('Canteen');



subplot(2,2,4)
plot(bla,out(range,2),'b');
set(gca,'YLim',[-0.1 1.3]);
xlabel('Time (sec)');

att = struct('peak',0,'valley',0);
rel = struct('peak',0,'valley',0);

clc;
[att.peak, rel.peak] = AttRelTimes(att_peak,rel_peak,blkFreq);
[att.valley, rel.valley] = AttRelTimes(att_valley,rel_valley,blkFreq);


    function d = Peak(x, d, a, b)                
        
        if(abs(x) >= d)
            d = a * d + (1-a)*abs(x);
        else
            d = (1 - 1/b) * d;
        end
    end


    function v = Valley(x, v, a, b)               
        
        if(abs(x) <= v)
            v = a * v + (1-a)*abs(x);
        else
            v = (1 + 1/b) * v;
        end
    end



    function out = detect(peak, valley, threshold)
        
        out = 20*log10(peak/valley) > threshold;
        
    end

    function [att, rel] = AttRelTimes(a, b, fs)
        
        att = - 2.3 / fs / log(1 - a) * 1e3;
        rel = - 2.3 / fs / log(1 - 1/b) * 1e3;

    end
end





