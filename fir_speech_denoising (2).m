
clc;
clear;
close all;

%% STEP 1: Load the input speech
[audio, Fs] = audioread('speech.wav');

% Convert stereo audio to mono if needed
if size(audio, 2) == 2
    audio = mean(audio, 2);
end

% Normalize the speech signal
audio = audio / max(abs(audio));

fprintf('Original speech loaded successfully.\n');
fprintf('Sampling frequency: %d Hz\n', Fs);
fprintf('Duration: %.2f seconds\n', length(audio)/Fs);

%% STEP 2: Resample speech to 16 kHz
targetFs = 16000;

speech = resample(audio, targetFs, Fs);
Fs = targetFs;

% Create time axis
t = (0:length(speech)-1)' / Fs;

%% STEP 3: Display original speech
figure;
plot(t, speech);
xlabel('Time (seconds)');
ylabel('Amplitude');
title('Original Speech Signal');
grid on;

%% STEP 4: Add synthetic white Gaussian noise
rng(42);

inputSNR = 5;  % Desired input SNR in dB

noise = randn(size(speech));

speechPower = mean(speech.^2);
noisePower = mean(noise.^2);

noise = noise * sqrt( ...
    speechPower / (noisePower * 10^(inputSNR/10)));

noisySpeech = speech + noise;

%% STEP 5: Display noisy speech
figure;
plot(t, noisySpeech);
xlabel('Time (seconds)');
ylabel('Amplitude');
title('Speech with Synthetic White Noise');
grid on;

%% STEP 6: Play the noisy speech
disp('Playing speech with added synthetic noise...');
sound(noisySpeech, Fs);

%% STEP 7: Design three FIR filters

filterOrder = 100;
cutoffFreq = 3400;
normalizedCutoff = cutoffFreq / (Fs/2);

% Define the three window functions
rectWindow = rectwin(filterOrder + 1);
hammingWindow = hamming(filterOrder + 1);
hannWindow = hann(filterOrder + 1);

% Design equal-specification low-pass FIR filters
bRect = fir1(filterOrder, normalizedCutoff, ...
    'low', rectWindow);

bHamming = fir1(filterOrder, normalizedCutoff, ...
    'low', hammingWindow);

bHann = fir1(filterOrder, normalizedCutoff, ...
    'low', hannWindow);

disp('All three FIR filters designed successfully.');

%% STEP 8: Filter the noisy speech

filteredRect = filter(bRect, 1, noisySpeech);
filteredHamming = filter(bHamming, 1, noisySpeech);
filteredHann = filter(bHann, 1, noisySpeech);

%% STEP 9: Plot all filtered speech signals

figure;

subplot(3,1,1);
plot(t, filteredRect);
title('Rectangular Window FIR Output');
xlabel('Time (seconds)');
ylabel('Amplitude');
grid on;

subplot(3,1,2);
plot(t, filteredHamming);
title('Hamming Window FIR Output');
xlabel('Time (seconds)');
ylabel('Amplitude');
grid on;

subplot(3,1,3);
plot(t, filteredHann);
title('Hann Window FIR Output');
xlabel('Time (seconds)');
ylabel('Amplitude');
grid on;

sgtitle('Comparison of Filtered Speech Signals');

%% Improved Frequency Response Comparison

figure;

[Hrect, Frect] = freqz(bRect, 1, 4096, Fs);
[Hham, Fham] = freqz(bHamming, 1, 4096, Fs);
[Hhann, Fhann] = freqz(bHann, 1, 4096, Fs);

plot(Frect, 20*log10(abs(Hrect)+eps), 'LineWidth', 1.5);
hold on;
plot(Fham, 20*log10(abs(Hham)+eps), 'LineWidth', 1.5);
plot(Fhann, 20*log10(abs(Hhann)+eps), 'LineWidth', 1.5);

grid on;
xlim([0 Fs/2]);
ylim([-100 5]);

xlabel('Frequency (Hz)');
ylabel('Magnitude (dB)');
title('FIR Window Frequency Response Comparison');

legend('Rectangular', 'Hamming', 'Hann', ...
    'Location', 'southwest');

xline(3400, '--k', 'Cutoff Frequency');

hold off;

saveas(gcf, '04_frequency_response_improved.png');


%% STEP 11: Save filtered audio files

audiowrite('rectangular_filtered.wav', ...
    filteredRect, Fs);

audiowrite('hamming_filtered.wav', ...
    filteredHamming, Fs);

audiowrite('hann_filtered.wav', ...
    filteredHann, Fs);

disp('Filtered audio files saved successfully.');

%% STEP 12: Performance Evaluation using SNR and MSE

% Compensate for the FIR filter's group delay
delay = filterOrder / 2;

% Align the clean speech and noisy speech with filtered outputs
reference = speech(1:end-delay);
noisyAligned = noisySpeech(1:end-delay);

rectAligned = filteredRect(delay+1:end);
hammingAligned = filteredHamming(delay+1:end);
hannAligned = filteredHann(delay+1:end);

% Function to calculate SNR
calculateSNR = @(ref, test) ...
    10*log10(sum(ref.^2) / ...
    max(sum((ref-test).^2), eps));

% Calculate noisy input SNR
snrNoisy = calculateSNR(reference, noisyAligned);

% Calculate SNR for each filtered signal
snrRect = calculateSNR(reference, rectAligned);
snrHamming = calculateSNR(reference, hammingAligned);
snrHann = calculateSNR(reference, hannAligned);

% Calculate SNR improvement
improvementRect = snrRect - snrNoisy;
improvementHamming = snrHamming - snrNoisy;
improvementHann = snrHann - snrNoisy;

% Calculate mean squared error (MSE)
mseRect = mean((reference - rectAligned).^2);
mseHamming = mean((reference - hammingAligned).^2);
mseHann = mean((reference - hannAligned).^2);

% Display the results
Window = {'Rectangular'; 'Hamming'; 'Hann'};

Output_SNR_dB = [snrRect; snrHamming; snrHann];
SNR_Improvement_dB = [improvementRect; ...
    improvementHamming; improvementHann];
MSE = [mseRect; mseHamming; mseHann];

Results = table(Window, Output_SNR_dB, ...
    SNR_Improvement_dB, MSE);

disp(' ');
disp('FIR SPEECH DENOISING PERFORMANCE RESULTS');
disp(Results);

% Save the numerical results
writetable(Results, 'FIR_Performance_Results.csv');

disp('Performance results saved to FIR_Performance_Results.csv');


%% Improved Performance Comparison Graphs

windowNames = categorical( ...
    {'Rectangular','Hamming','Hann'});

windowNames = reordercats(windowNames, ...
    {'Rectangular','Hamming','Hann'});

snrValues = [snrRect, snrHamming, snrHann];
improvementValues = [improvementRect, ...
    improvementHamming, improvementHann];
mseValues = [mseRect, mseHamming, mseHann];

% Output SNR
figure;
bar(windowNames, snrValues);
ylim([7.75 7.90]);
ylabel('Output SNR (dB)');
xlabel('Window Function');
title('Output SNR Comparison');
grid on;
saveas(gcf, '06_output_snr.png');

% SNR Improvement
figure;
bar(windowNames, improvementValues);
ylim([2.75 2.92]);
ylabel('SNR Improvement (dB)');
xlabel('Window Function');
title('SNR Improvement Comparison');
grid on;
saveas(gcf, '07_snr_improvement.png');

% Mean Squared Error
figure;
bar(windowNames, mseValues);
ylim([0.00405 0.00416]);
ylabel('Mean Squared Error');
xlabel('Window Function');
title('MSE Comparison');
grid on;
saveas(gcf, '08_mse_comparison.png');

disp('Improved comparison graphs saved successfully.');