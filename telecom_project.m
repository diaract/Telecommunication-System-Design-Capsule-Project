%% ========================================================================
%%   EE3001 TELECOM PROJECT  -  COMPLETE INTEGRATED PIPELINE
%%   Single file, single load, no intermediate saving
%%   PART 1 : DSP      (Filter, Downsample, LPC/LSF, Pitch, Binary)
%%   PART 2 : BPSK     (Modulation, USRP TX/RX, Demodulation, BER)
%%   PART 3 : Synthesis (Bit decode, Parametric vocoder, Quality)
%%   PART 4 : Simulation (BER vs Eb/N0, AWGN channel)
%%
%%   ONLY EXTERNAL DEPENDENCY: x_corrupt.mat
%% ========================================================================

clear; close all; clc;

fprintf('\n');
fprintf('════════════════════════════════════════════════════════════════════\n');
fprintf('         EE3001 TELECOM PROJECT - COMPLETE INTEGRATED PIPELINE\n');
fprintf('════════════════════════════════════════════════════════════════════\n\n');
pause(0.5);

%% ========================================================================
%% PART 1: DSP - SIGNAL PROCESSING PIPELINE
%% ========================================================================

fprintf('\n════════════════════════════════════════════════════════════════════\n');
fprintf('  PART 1: DSP - SIGNAL PROCESSING PIPELINE\n');
fprintf('════════════════════════════════════════════════════════════════════\n\n');

%% ========================================================================
%% STEP 1: LOAD CORRUPTED SIGNAL AND ANALYZE
%% ========================================================================

fprintf('════════════════════════════════════════════════════════════════════\n');
fprintf('STEP 1: CORRUPTED SIGNAL LOADING AND INITIAL ANALYSIS\n');
fprintf('════════════════════════════════════════════════════════════════════\n\n');

load('x_corrupt.mat');   

if exist('x_corrupt', 'var')
    x = x_corrupt;
elseif exist('x', 'var')
    % x already exists
else
    error('Signal variable not found!');
end

Fs_original = 48000;
N           = length(x);
t           = (0:N-1) / Fs_original;
duration    = N / Fs_original;

fprintf('SIGNAL INFORMATION:\n');
fprintf('  File: x_corrupt.mat\n');
fprintf('  Number of samples: %d\n', N);
fprintf('  Sampling frequency: %d Hz\n', Fs_original);
fprintf('  Duration: %.3f seconds\n', duration);
fprintf('  Min: %.4f  Max: %.4f\n', min(x), max(x));
fprintf('  RMS: %.4f\n', sqrt(mean(x.^2)));
fprintf('  Data size: %d bytes (%.2f KB)\n', N*2, N*2/1024);

NFFT   = 2^nextpow2(N);
X      = fft(x, NFFT);
X_mag  = abs(X(1:NFFT/2+1));
f      = Fs_original * (0:(NFFT/2)) / NFFT;

figure('Name','STEP 1: Corrupted Signal','Position',[50 50 1600 900]);

subplot(3,3,1);
plot(t, x,'b','LineWidth',0.5);
xlabel('Time (s)'); ylabel('Amplitude');
title('Corrupted Speech Signal (48 kHz)');
grid on; xlim([0 min(1,duration)]);

subplot(3,3,2);
plot(f/1000, 20*log10(X_mag+eps),'r','LineWidth',1);
hold on; xline(3.4,'g--','LineWidth',2,'Label','Target Cutoff');
xlabel('Frequency (kHz)'); ylabel('Magnitude (dB)');
title('FFT Magnitude (dB)'); grid on; xlim([0 24]);

subplot(3,3,3);
idx_4kHz = find(f <= 4000, 1,'last');
plot(f(1:idx_4kHz)/1000, 20*log10(X_mag(1:idx_4kHz)+eps),'g','LineWidth',2);
hold on; xline(3.4,'r--','LineWidth',2);
xlabel('Frequency (kHz)'); ylabel('Magnitude (dB)');
title('Speech Band (0-4 kHz)'); grid on;

subplot(3,3,[4 5 6]);
spectrogram(x,hamming(round(0.03*Fs_original)),round(0.015*Fs_original),2048,Fs_original,'yaxis');
title('Spectrogram - Corrupted (High-frequency noise visible)');
ylim([0 24]); colorbar;

subplot(3,3,7);
histogram(x,50,'FaceColor','b','EdgeAlpha',0.3);
xlabel('Amplitude'); ylabel('Count'); title('Amplitude Distribution'); grid on;

subplot(3,3,8);
[pxx,f_psd] = pwelch(x,hamming(1024),512,2048,Fs_original);
plot(f_psd/1000,10*log10(pxx),'b','LineWidth',1.5);
xlabel('Frequency (kHz)'); ylabel('PSD (dB/Hz)');
title('Power Spectral Density'); grid on; xlim([0 24]);

subplot(3,3,9);
text(0.1,0.9,'PROBLEM DETECTION:','FontSize',12,'FontWeight','bold');
text(0.1,0.75,'High-frequency noise exists (>4 kHz)');
text(0.1,0.65,'48 kHz unnecessarily high for speech');
text(0.1,0.55,'Data size is large');
text(0.1,0.40,'SOLUTION:','FontSize',12,'FontWeight','bold');
text(0.1,0.25,'Anti-aliasing filter (3.4 kHz cutoff)');
text(0.1,0.15,'Downsampling (48 kHz to 8 kHz)');
text(0.1,0.05,'LPC/LSF compression'); axis off;

fprintf('\n  Press ENTER to continue to filtering...\n'); pause;

%% ========================================================================
%% STEP 2: ANTI-ALIASING FILTER
%% ========================================================================

fprintf('\n════════════════════════════════════════════════════════════════════\n');
fprintf('STEP 2: ANTI-ALIASING FILTER DESIGN AND APPLICATION\n');
fprintf('════════════════════════════════════════════════════════════════════\n\n');

Fc           = 3400;
filter_order = 100;
Wn           = Fc / (Fs_original/2);

fprintf('FILTER PARAMETERS:\n');
fprintf('  Type: FIR (Kaiser window)\n');
fprintf('  Order: %d\n', filter_order);
fprintf('  Cutoff: %d Hz (%.1f kHz)\n', Fc, Fc/1000);
fprintf('  Normalized cutoff: %.4f\n', Wn);

b_fir      = fir1(filter_order, Wn, 'low', kaiser(filter_order+1, 5));
a_fir      = 1;
x_filtered = filtfilt(b_fir, a_fir, x);

X_filtered     = fft(x_filtered, NFFT);
X_filtered_mag = abs(X_filtered(1:NFFT/2+1));

fprintf('  Energy loss: %.2f%%\n', (1 - sum(x_filtered.^2)/sum(x.^2))*100);

figure('Name','STEP 2: Anti-Aliasing Filtering','Position',[50 50 1600 800]);

subplot(2,3,1);
[H_fir,W_fir] = freqz(b_fir,a_fir,2048,Fs_original);
plot(W_fir/1000,20*log10(abs(H_fir)),'b','LineWidth',2);
hold on; xline(Fc/1000,'r--','LineWidth',2);
xlabel('Frequency (kHz)'); ylabel('Magnitude (dB)');
title('Filter Frequency Response'); grid on; xlim([0 8]); ylim([-80 5]);

subplot(2,3,2);
plot(t,x,'b','LineWidth',0.5); hold on;
plot(t,x_filtered,'r','LineWidth',0.8);
xlabel('Time (s)'); ylabel('Amplitude'); title('Time Domain');
legend('Corrupted','Filtered'); grid on; xlim([0 min(0.5,duration)]);

subplot(2,3,3);
plot(f/1000,20*log10(X_mag+eps),'b','LineWidth',1); hold on;
plot(f/1000,20*log10(X_filtered_mag+eps),'r','LineWidth',1.5);
xline(3.4,'g--','LineWidth',2);
xlabel('Frequency (kHz)'); ylabel('Magnitude (dB)');
title('Spectrum Comparison');
legend('Corrupted','Filtered','Cutoff'); grid on; xlim([0 12]);

subplot(2,3,4);
spectrogram(x,hamming(round(0.03*Fs_original)),round(0.015*Fs_original),1024,Fs_original,'yaxis');
title('Corrupted - Spectrogram'); ylim([0 12]); colorbar;

subplot(2,3,5);
spectrogram(x_filtered,hamming(round(0.03*Fs_original)),round(0.015*Fs_original),1024,Fs_original,'yaxis');
title('Filtered - Spectrogram'); ylim([0 12]); colorbar;

subplot(2,3,6);
text(0.1,0.9,'RESULTS:','FontSize',12,'FontWeight','bold');
text(0.1,0.75,sprintf('>3.4 kHz noise removed'));
text(0.1,0.65,sprintf('Energy loss: %.1f%%',(1-sum(x_filtered.^2)/sum(x.^2))*100));
text(0.1,0.55,'Audio quality preserved');
text(0.1,0.40,'NEXT STEP:','FontSize',12,'FontWeight','bold');
text(0.1,0.25,'48 kHz -> 8 kHz downsampling'); axis off;

fprintf('  Press ENTER to continue to downsampling...\n'); pause;

%% ========================================================================
%% STEP 3: DOWNSAMPLING (48 kHz → 8 kHz)
%% ========================================================================

fprintf('\n════════════════════════════════════════════════════════════════════\n');
fprintf('STEP 3: DOWNSAMPLING (48 kHz -> 8 kHz)\n');
fprintf('════════════════════════════════════════════════════════════════════\n\n');

Fs_target         = 8000;
decimation_factor = Fs_original / Fs_target;

fprintf('  Original Fs: %d Hz\n', Fs_original);
fprintf('  Target Fs:   %d Hz\n', Fs_target);
fprintf('  Decimation:  %d\n', decimation_factor);

x_downsampled = x_filtered(1:decimation_factor:end);
N_down        = length(x_downsampled);
t_down        = (0:N_down-1) / Fs_target;

bytes_original = N * 2;
bytes_8k       = N_down * 2;

fprintf('\n  %d -> %d samples\n', length(x_filtered), N_down);
fprintf('  %.2f KB -> %.2f KB\n', bytes_original/1024, bytes_8k/1024);
fprintf('  Reduction: 1:%d\n', decimation_factor);

NFFT_8k   = 2^nextpow2(N_down);
X_8k      = fft(x_downsampled, NFFT_8k);
X_8k_mag  = abs(X_8k(1:NFFT_8k/2+1));
f_8k      = Fs_target * (0:(NFFT_8k/2)) / NFFT_8k;

figure('Name','STEP 3: Downsampling','Position',[50 50 1600 800]);

subplot(2,3,1);
plot(t,x_filtered,'b','LineWidth',0.5); hold on;
plot(t_down,x_downsampled,'r.','MarkerSize',4);
xlabel('Time (s)'); ylabel('Amplitude'); title('48 kHz vs 8 kHz');
legend('48 kHz','8 kHz'); grid on; xlim([0 min(0.1,t_down(end))]);

subplot(2,3,2);
plot(f_8k/1000,20*log10(X_8k_mag+eps),'r','LineWidth',1.5);
xlabel('Frequency (kHz)'); ylabel('Magnitude (dB)');
title('Spectrum (8 kHz)'); grid on; xlim([0 4]);

subplot(2,3,3);
bar([bytes_original/1024, bytes_8k/1024],'FaceColor',[0.3 0.6 0.9]);
set(gca,'XTickLabel',{'48 kHz','8 kHz'}); ylabel('KB'); title('Data Size'); grid on;
text(1,bytes_original/1024*1.05,sprintf('%.1f KB',bytes_original/1024),'HorizontalAlignment','center','FontWeight','bold');
text(2,bytes_8k/1024*1.05,sprintf('%.1f KB',bytes_8k/1024),'HorizontalAlignment','center','FontWeight','bold');

subplot(2,3,4);
spectrogram(x_filtered,hamming(round(0.03*Fs_original)),round(0.015*Fs_original),1024,Fs_original,'yaxis');
title('48 kHz - Spectrogram'); ylim([0 4]); colorbar;

subplot(2,3,5);
spectrogram(x_downsampled,hamming(round(0.03*Fs_target)),round(0.015*Fs_target),512,Fs_target,'yaxis');
title('8 kHz - Spectrogram'); ylim([0 4]); colorbar;

subplot(2,3,6);
text(0.1,0.9,'RESULTS:','FontSize',12,'FontWeight','bold');
text(0.1,0.75,sprintf('Data reduced 1:%d',decimation_factor));
text(0.1,0.65,'Telephone band preserved');
text(0.1,0.55,sprintf('%.2f KB -> %.2f KB',bytes_original/1024,bytes_8k/1024)); axis off;


fprintf('\n  8 kHz signal ready. Audio playback will be at the end (Part 3).\n\n');

%% ========================================================================
%% STEP 4A: LPC/LSF ANALYSIS
%% ========================================================================

fprintf('\n════════════════════════════════════════════════════════════════════\n');
fprintf('STEP 4A: LPC/LSF ANALYSIS\n');
fprintf('════════════════════════════════════════════════════════════════════\n\n');

lpc_order          = 12;
frame_length_ms    = 30;
frame_overlap      = 0.5;
frame_length_samples = round(frame_length_ms * Fs_target / 1000);
frame_shift_samples  = round(frame_length_samples * (1 - frame_overlap));
N_signal           = length(x_downsampled);
num_frames         = floor((N_signal - frame_length_samples) / frame_shift_samples) + 1;
win                = hann(frame_length_samples);

fprintf('LPC PARAMETERS:\n');
fprintf('  LPC order:     %d\n', lpc_order);
fprintf('  Frame:         %d ms (%d samples)\n', frame_length_ms, frame_length_samples);
fprintf('  Overlap:       %.0f%%\n', frame_overlap*100);
fprintf('  Total frames:  %d\n\n', num_frames);

lpc_coeffs = zeros(num_frames, lpc_order+1);
lsf_params = zeros(num_frames, lpc_order);
gains      = zeros(num_frames, 1);
residuals  = cell(num_frames, 1);

fprintf('LPC analysis running...\n');
for i = 1:num_frames
    s_idx = (i-1)*frame_shift_samples + 1;
    e_idx = s_idx + frame_length_samples - 1;
    if e_idx > N_signal; break; end
    frame           = x_downsampled(s_idx:e_idx) .* win;
    [a, g]          = lpc(frame, lpc_order);
    lpc_coeffs(i,:) = a;
    gains(i)        = g;
    lsf_params(i,:) = poly2lsf(a);
    residuals{i}    = filter(a, 1, x_downsampled(s_idx:e_idx));
    if mod(i,10)==0; fprintf('  Frame %d/%d\n',i,num_frames); end
end
fprintf('  LPC analysis completed!\n');

t_frames  = (0:num_frames-1) * frame_shift_samples / Fs_target;
gain_db   = 10*log10(gains + eps);
lsf_hz    = lsf_params * Fs_target / (2*pi);

fprintf('\nSTATISTICS:\n');
fprintf('  Gain: %.2f to %.2f dB (mean: %.2f)\n',min(gain_db),max(gain_db),mean(gain_db));
fprintf('  LSF:  %.1f to %.1f Hz\n',min(lsf_hz(:)),max(lsf_hz(:)));

figure('Name','STEP 4A: LPC/LSF Analysis','Position',[50 50 1600 800]);

subplot(2,3,1);
plot(t_down,x_downsampled,'b','LineWidth',0.5);
xlabel('Time (s)'); ylabel('Amplitude'); title('Clean Signal (8 kHz)'); grid on;

subplot(2,3,2);
plot(t_frames,lsf_hz,'LineWidth',1.5);
xlabel('Time (s)'); ylabel('Frequency (Hz)'); title('LSF Parameters'); grid on;

subplot(2,3,3);
plot(t_frames,gain_db,'r','LineWidth',1.5);
xlabel('Time (s)'); ylabel('Gain (dB)'); title('Frame Gain'); grid on;

subplot(2,3,4);
imagesc(t_frames,1:lpc_order,lsf_hz'); colorbar;
xlabel('Time (s)'); ylabel('LSF Index'); title('LSF Heat Map'); colormap(jet);

subplot(2,3,5);
histogram(lsf_hz(:),50,'FaceColor','b','EdgeAlpha',0.3);
xlabel('Frequency (Hz)'); ylabel('Count'); title('LSF Distribution'); grid on;

subplot(2,3,6);
ef = round(num_frames/2);
si = (ef-1)*frame_shift_samples+1; ei = si+frame_length_samples-1;
frame_ex = x_downsampled(si:ei) .* win;
[pxx_f,f_psd_f] = pwelch(frame_ex,hamming(length(frame_ex)),[],512,Fs_target);
[h_lpc,f_lpc]   = freqz(sqrt(gains(ef)),lpc_coeffs(ef,:),512,Fs_target);
plot(f_psd_f,10*log10(pxx_f),'b','LineWidth',1.5); hold on;
plot(f_lpc,20*log10(abs(h_lpc)),'r--','LineWidth',2);
xlabel('Frequency (Hz)'); ylabel('Power (dB)');
title(sprintf('Frame %d: Actual vs LPC',ef));
legend('Actual','LPC'); grid on;

fprintf('\n  Press ENTER to continue...\n'); pause;

%% ========================================================================
%% STEP 4B: PITCH AND VOICED/UNVOICED DETECTION
%% ========================================================================

fprintf('\n════════════════════════════════════════════════════════════════════\n');
fprintf('STEP 4B: PITCH AND VOICED/UNVOICED DETECTION\n');
fprintf('════════════════════════════════════════════════════════════════════\n\n');

min_pitch         = 80;
max_pitch         = 400;
voicing_threshold = 0.3;
min_lag           = round(Fs_target / max_pitch);
max_lag           = round(Fs_target / min_pitch);

fprintf('PITCH DETECTION:\n');
fprintf('  Method: Autocorrelation\n');
fprintf('  Range: %d-%d Hz\n', min_pitch, max_pitch);
fprintf('  Voicing threshold: %.2f\n\n', voicing_threshold);

pitch_values     = zeros(num_frames, 1);
is_voiced        = zeros(num_frames, 1);
voicing_strength = zeros(num_frames, 1);

fprintf('Pitch detection running...\n');
for i = 1:num_frames
    s_idx = (i-1)*frame_shift_samples + 1;
    e_idx = s_idx + frame_length_samples - 1;
    if e_idx > N_signal; break; end
    frame_w          = x_downsampled(s_idx:e_idx) .* win;
    [acf, lags]      = xcorr(frame_w, frame_w, 'coeff');
    acf_pos          = acf(lags >= 0);
    lags_pos         = lags(lags >= 0);
    acf_search       = acf_pos(min_lag+1 : max_lag+1);
    lags_search      = lags_pos(min_lag+1 : max_lag+1);
    [max_acf, midx]  = max(acf_search);
    pitch_lag        = lags_search(midx);
    voicing_strength(i) = max_acf;
    if max_acf > voicing_threshold
        is_voiced(i)    = 1;
        pitch_values(i) = Fs_target / pitch_lag;
    end
    if mod(i,10)==0; fprintf('  Frame %d/%d\n',i,num_frames); end
end
fprintf('  Pitch detection completed!\n');

num_voiced   = sum(is_voiced);
voiced_pitch = pitch_values(is_voiced == 1);

fprintf('\nSTATISTICS:\n');
fprintf('  Voiced:   %d frames (%.1f%%)\n', num_voiced, num_voiced/num_frames*100);
fprintf('  Unvoiced: %d frames (%.1f%%)\n', sum(~is_voiced), sum(~is_voiced)/num_frames*100);
fprintf('  Pitch:    %.1f Hz (%.1f-%.1f Hz)\n', mean(voiced_pitch),min(voiced_pitch),max(voiced_pitch));

figure('Name','STEP 4B: Pitch & Voiced/Unvoiced','Position',[50 50 1600 800]);

subplot(2,3,1);
voiced_frames_idx = find(is_voiced);
plot(t_frames(voiced_frames_idx),pitch_values(voiced_frames_idx),'g.','MarkerSize',12);
xlabel('Time (s)'); ylabel('Pitch (Hz)'); title('Pitch (Voiced Frames)');
grid on; ylim([min_pitch-20, max_pitch+20]);

subplot(2,3,2);
stairs(t_frames,is_voiced,'b','LineWidth',1.5);
xlabel('Time (s)'); ylabel('Voiced=1 / Unvoiced=0');
title('Voiced/Unvoiced'); ylim([-0.2 1.2]); grid on;

subplot(2,3,3);
histogram(voiced_pitch,30,'FaceColor','g','EdgeAlpha',0.3);
xlabel('Pitch (Hz)'); ylabel('Count');
title(sprintf('Pitch Distribution (Mean: %.1f Hz)',mean(voiced_pitch))); grid on;

subplot(2,3,4);
plot(t_frames,voicing_strength,'m','LineWidth',1.5); hold on;
yline(voicing_threshold,'r--','LineWidth',2);
xlabel('Time (s)'); ylabel('ACF Peak'); title('Voicing Strength'); grid on;

subplot(2,3,5);
bar([num_voiced, sum(~is_voiced)],'FaceColor',[0.3 0.6 0.9]);
set(gca,'XTickLabel',{'Voiced','Unvoiced'}); ylabel('Count'); grid on;

subplot(2,3,6);
text(0.1,0.9,'RESULTS:','FontSize',12,'FontWeight','bold');
text(0.1,0.75,sprintf('Pitch: %.1f Hz average',mean(voiced_pitch)));
text(0.1,0.65,sprintf('Voiced: %.1f%%',num_voiced/num_frames*100));
text(0.1,0.55,sprintf('Unvoiced: %.1f%%',sum(~is_voiced)/num_frames*100));
text(0.1,0.40,'USAGE:','FontSize',12,'FontWeight','bold');
text(0.1,0.25,'For parametric vocoder'); axis off;

fprintf('\n  Press ENTER to continue...\n'); pause;

%% ========================================================================
%% STEP 5A: RESIDUAL-BASED VOCODER
%% ========================================================================

fprintf('\n════════════════════════════════════════════════════════════════════\n');
fprintf('STEP 5A: RESIDUAL-BASED VOCODER (RMS MATCHED)\n');
fprintf('════════════════════════════════════════════════════════════════════\n\n');

x_synth_residual = zeros(size(x_downsampled));
overlap_count    = zeros(size(x_downsampled));

for i = 1:num_frames
    s_idx = (i-1)*frame_shift_samples+1;
    e_idx = s_idx + frame_length_samples-1;
    if e_idx > length(x_synth_residual); break; end
    a         = lpc_coeffs(i,:);
    orig_frame = x_downsampled(s_idx:e_idx);
    sf        = filter(1, a, residuals{i});
    orig_rms  = sqrt(mean(orig_frame.^2));
    synth_rms = sqrt(mean(sf.^2));
    if synth_rms > eps; sf = sf*(orig_rms/synth_rms); end
    sf_w = sf .* win;
    x_synth_residual(s_idx:e_idx) = x_synth_residual(s_idx:e_idx) + sf_w;
    overlap_count(s_idx:e_idx)    = overlap_count(s_idx:e_idx)    + win;
    if mod(i,10)==0; fprintf('  Frame %d/%d\n',i,num_frames); end
end
overlap_count(overlap_count < 0.01) = 1;
x_synth_residual = x_synth_residual ./ overlap_count;
x_synth_residual = x_synth_residual / max(abs(x_synth_residual)) * 0.95;

cc_res  = corrcoef(x_downsampled, x_synth_residual);
snr_res = 10*log10(sum(x_downsampled.^2) / sum((x_downsampled-x_synth_residual).^2));
fprintf('  Correlation: %.4f  |  SNR: %.2f dB\n', cc_res(1,2), snr_res);

%% ========================================================================
%% STEP 5B: PARAMETRIC VOCODER
%% ========================================================================

fprintf('\n════════════════════════════════════════════════════════════════════\n');
fprintf('STEP 5B: PARAMETRIC VOCODER (PITCH-BASED)\n');
fprintf('════════════════════════════════════════════════════════════════════\n\n');

x_synth_parametric = zeros(size(x_downsampled));
overlap_count_p    = zeros(size(x_downsampled));

for i = 1:num_frames
    s_idx = (i-1)*frame_shift_samples+1;
    e_idx = s_idx + frame_length_samples-1;
    if e_idx > length(x_synth_parametric); break; end
    a         = lpc_coeffs(i,:);
    orig_frame = x_downsampled(s_idx:e_idx);
    if is_voiced(i)
        pitch_period = round(Fs_target / pitch_values(i));
        excitation   = zeros(frame_length_samples,1);
        excitation(1:pitch_period:end) = 1.0;
    else
        excitation = randn(frame_length_samples,1);
    end
    sf        = filter(1, a, excitation);
    orig_rms  = sqrt(mean(orig_frame.^2));
    synth_rms = sqrt(mean(sf.^2));
    if synth_rms > eps; sf = sf*(orig_rms/synth_rms); end
    sf_w = sf .* win;
    x_synth_parametric(s_idx:e_idx) = x_synth_parametric(s_idx:e_idx) + sf_w;
    overlap_count_p(s_idx:e_idx)    = overlap_count_p(s_idx:e_idx)    + win;
    if mod(i,10)==0; fprintf('  Frame %d/%d\n',i,num_frames); end
end
overlap_count_p(overlap_count_p < 0.01) = 1;
x_synth_parametric = x_synth_parametric ./ overlap_count_p;
x_synth_parametric = x_synth_parametric / max(abs(x_synth_parametric)) * 0.95;

cc_par  = corrcoef(x_downsampled, x_synth_parametric);
snr_par = 10*log10(sum(x_downsampled.^2) / sum((x_downsampled-x_synth_parametric).^2));
fprintf('  Correlation: %.4f  |  SNR: %.2f dB\n', cc_par(1,2), snr_par);

% Comparison figure
figure('Name','STEP 5: Vocoder Comparison','Position',[50 50 1600 900]);

subplot(3,3,1); plot(t_down,x_downsampled,'b','LineWidth',0.8);
xlabel('Time (s)'); ylabel('Amplitude'); title('Original'); grid on; ylim([-1 1]);
subplot(3,3,2); plot(t_down,x_synth_residual,'r','LineWidth',0.8);
xlabel('Time (s)'); title(sprintf('Residual (SNR: %.2f dB)',snr_res)); grid on; ylim([-1 1]);
subplot(3,3,3); plot(t_down,x_synth_parametric,'g','LineWidth',0.8);
xlabel('Time (s)'); title(sprintf('Parametric (SNR: %.2f dB)',snr_par)); grid on; ylim([-1 1]);

subplot(3,3,4);
[Pxx_o,f_p] = pwelch(x_downsampled,hamming(1024),512,2048,Fs_target);
[Pxx_r,~]   = pwelch(x_synth_residual,hamming(1024),512,2048,Fs_target);
[Pxx_p,~]   = pwelch(x_synth_parametric,hamming(1024),512,2048,Fs_target);
plot(f_p,10*log10(Pxx_o),'b','LineWidth',2); hold on;
plot(f_p,10*log10(Pxx_r),'r--','LineWidth',2);
plot(f_p,10*log10(Pxx_p),'g-.','LineWidth',2);
legend('Original','Residual','Parametric');
xlabel('Hz'); ylabel('PSD (dB/Hz)'); grid on; xlim([0 4000]);

subplot(3,3,5);
spectrogram(x_downsampled,hamming(256),128,512,Fs_target,'yaxis');
title('Original'); ylim([0 4]); colorbar;
subplot(3,3,6);
spectrogram(x_synth_residual,hamming(256),128,512,Fs_target,'yaxis');
title('Residual'); ylim([0 4]); colorbar;
subplot(3,3,7);
spectrogram(x_synth_parametric,hamming(256),128,512,Fs_target,'yaxis');
title('Parametric'); ylim([0 4]); colorbar;

subplot(3,3,8);
bar([cc_res(1,2)*100; cc_par(1,2)*100],'FaceColor',[0.3 0.6 0.9]);
set(gca,'XTickLabel',{'Residual','Parametric'}); ylabel('Correlation x100'); grid on;
subplot(3,3,9);
bar([snr_res; snr_par],'FaceColor',[0.8 0.3 0.3]);
set(gca,'XTickLabel',{'Residual','Parametric'}); ylabel('SNR (dB)'); grid on;

fprintf('\n  Press ENTER to continue to quantization...\n'); pause;

%% ========================================================================
%% STEP 6: QUANTIZATION + BINARY DATA
%% ========================================================================

fprintf('\n════════════════════════════════════════════════════════════════════\n');
fprintf('STEP 6: QUANTIZATION + BINARY DATA\n');
fprintf('════════════════════════════════════════════════════════════════════\n\n');

lsf_bits    = 8;
gain_bits   = 8;
pitch_bits  = 7;
voiced_bits = 1;
bits_per_frame = lpc_order*lsf_bits + gain_bits + pitch_bits + voiced_bits;

fprintf('FRAME STRUCTURE:\n');
fprintf('  LSF:   %d x %d = %d bits\n', lpc_order, lsf_bits, lpc_order*lsf_bits);
fprintf('  Gain:  %d bits\n', gain_bits);
fprintf('  Pitch: %d bits\n', pitch_bits);
fprintf('  V/UV:  %d bit\n', voiced_bits);
fprintf('  TOTAL: %d bits/frame\n\n', bits_per_frame);

% LSF Quantization
lsf_quantized = zeros(num_frames, lpc_order);
for i = 1:num_frames
    lsf_q = round((lsf_params(i,:)/pi) * (2^lsf_bits-1));
    lsf_quantized(i,:) = max(0, min(2^lsf_bits-1, lsf_q));
end
fprintf('  LSF quantization done\n');

% Gain Quantization
gain_db_min   = min(gain_db);
gain_db_max   = max(gain_db);
gain_db_range = gain_db_max - gain_db_min;
if gain_db_range < eps; gain_db_range = 1; end
gain_normalized = (gain_db - gain_db_min) / gain_db_range;
gain_quantized  = max(0, min(2^gain_bits-1, round(gain_normalized*(2^gain_bits-1))));
fprintf('  Gain quantization done\n');

% Pitch Quantization
pitch_quantized = zeros(num_frames,1);
for i = 1:num_frames
    if is_voiced(i)==1 && pitch_values(i) > 0
        pn = (pitch_values(i)-min_pitch)/(max_pitch-min_pitch);
        pitch_quantized(i) = max(0, min(2^pitch_bits-1, round(pn*(2^pitch_bits-1))));
    end
end
voiced_quantized = uint8(is_voiced(:));
fprintf('  Pitch quantization done\n');

% Binary stream
binary_data = [];
for i = 1:num_frames
    for j = 1:lpc_order
        tmp = de2bi(lsf_quantized(i,j), lsf_bits, 'left-msb');
        binary_data = [binary_data; tmp(:)];
    end
    tmp = de2bi(gain_quantized(i), gain_bits, 'left-msb');
    binary_data = [binary_data; tmp(:)];
    tmp = de2bi(pitch_quantized(i), pitch_bits, 'left-msb');
    binary_data = [binary_data; tmp(:)];
    binary_data = [binary_data; voiced_quantized(i)];
end
binary_data  = binary_data(:);
total_bits   = length(binary_data);
total_bytes  = total_bits / 8;
num_zeros    = sum(binary_data == 0);
num_ones     = sum(binary_data == 1);

fprintf('\nBINARY DATA SUMMARY:\n');
fprintf('  Frames:      %d\n', num_frames);
fprintf('  Bits/frame:  %d\n', bits_per_frame);
fprintf('  Total bits:  %d\n', total_bits);
fprintf('  Total size:  %.3f KB\n', total_bytes/1024);
fprintf('  0 bits: %d  |  1 bits: %d\n', num_zeros, num_ones);

if total_bits == num_frames * bits_per_frame
    fprintf('  Binary size check: OK\n');
else
    fprintf('  Binary size check: MISMATCH!\n');
end

fprintf('\n  Compression: 1:%.0f\n', bytes_original/total_bytes);

% DSP Final Summary Figure
figure('Name','STEP 6: DSP Pipeline Overview','Position',[50 50 1800 1000]);

subplot(4,5,1);  plot(t,x,'b','LineWidth',0.5); xlabel('Time (s)'); title('1. CORRUPTED (48 kHz)'); grid on; xlim([0 0.5]);
subplot(4,5,2);  plot(t,x_filtered,'r','LineWidth',0.5); xlabel('Time (s)'); title('2. FILTERED'); grid on; xlim([0 0.5]);
subplot(4,5,3);  plot(t_down,x_downsampled,'g','LineWidth',0.8); xlabel('Time (s)'); title('3. 8 kHz'); grid on;
subplot(4,5,4);  plot(t_down,x_synth_residual,'m','LineWidth',0.8); xlabel('Time (s)'); title('4. RESIDUAL SYNTH'); grid on;
subplot(4,5,5);  plot(t_down,x_synth_parametric,'c','LineWidth',0.8); xlabel('Time (s)'); title('5. PARAMETRIC SYNTH'); grid on;

subplot(4,5,6);  spectrogram(x,hamming(round(0.03*Fs_original)),round(0.015*Fs_original),1024,Fs_original,'yaxis'); title('Corrupted'); ylim([0 12]); colorbar;
subplot(4,5,7);  spectrogram(x_filtered,hamming(round(0.03*Fs_original)),round(0.015*Fs_original),1024,Fs_original,'yaxis'); title('Filtered'); ylim([0 12]); colorbar;
subplot(4,5,8);  spectrogram(x_downsampled,hamming(round(0.03*Fs_target)),round(0.015*Fs_target),512,Fs_target,'yaxis'); title('8 kHz'); ylim([0 4]); colorbar;
subplot(4,5,9);  spectrogram(x_synth_residual,hamming(256),128,512,Fs_target,'yaxis'); title('Residual'); ylim([0 4]); colorbar;
subplot(4,5,10); spectrogram(x_synth_parametric,hamming(256),128,512,Fs_target,'yaxis'); title('Parametric'); ylim([0 4]); colorbar;

subplot(4,5,11); plot(t_frames,lsf_hz,'LineWidth',1.5); xlabel('Time (s)'); ylabel('Hz'); title('LSF Parameters'); grid on;
subplot(4,5,12); plot(t_frames,gain_db,'r','LineWidth',1.5); xlabel('Time (s)'); ylabel('dB'); title('Gain'); grid on;
subplot(4,5,13); plot(t_frames(voiced_frames_idx),pitch_values(voiced_frames_idx),'g.','MarkerSize',12); xlabel('Time (s)'); ylabel('Hz'); title('Pitch (Voiced)'); grid on; ylim([min_pitch-20, max_pitch+20]);
subplot(4,5,14); stairs(t_frames,is_voiced,'b','LineWidth',1.5); xlabel('Time (s)'); title('Voiced/Unvoiced'); ylim([-0.2 1.2]); grid on;
subplot(4,5,15); imagesc(t_frames,1:lpc_order,lsf_quantized'); colorbar; xlabel('Frame'); ylabel('LSF Index'); title('Quantized LSF');

subplot(4,5,16); stem(1:min(300,total_bits),binary_data(1:min(300,total_bits)),'b','MarkerSize',2); xlabel('Bit Index'); title('Binary Data (300 bits)'); grid on; ylim([-0.5 1.5]);
subplot(4,5,17); bar([num_zeros,num_ones],'FaceColor',[0.3 0.6 0.9]); set(gca,'XTickLabel',{'0','1'}); title('Bit Balance'); grid on;
subplot(4,5,18); sizes=[bytes_original/1024,bytes_8k/1024,total_bytes/1024]; b_bar=bar(sizes,'FaceColor','flat'); b_bar.CData=[0.8 0.2 0.2;0.2 0.6 0.8;0.2 0.8 0.2]; set(gca,'XTickLabel',{'48kHz','8kHz','Binary'}); ylabel('KB'); title('Data Size'); grid on;
subplot(4,5,19); comp=[1,bytes_original/bytes_8k,bytes_original/total_bytes]; bar(comp,'FaceColor',[0.3 0.7 0.4]); set(gca,'XTickLabel',{'Original','8kHz','Binary'}); ylabel('Compression'); title('Compression (1:X)'); grid on;

subplot(4,5,20);
text(0.05,0.95,'DSP SUMMARY','FontSize',11,'FontWeight','bold','Color','b');
text(0.05,0.80,sprintf('%.2f KB -> %.3f KB',bytes_original/1024,total_bytes/1024),'FontSize',9);
text(0.05,0.70,sprintf('Compression: 1:%.0f',bytes_original/total_bytes),'FontSize',9,'Color','r','FontWeight','bold');
text(0.05,0.57,'QUALITY:','FontSize',10,'FontWeight','bold');
text(0.05,0.47,sprintf('Residual: %.4f corr',cc_res(1,2)),'FontSize',9);
text(0.05,0.37,sprintf('SNR: %.2f dB',snr_res),'FontSize',9);
text(0.05,0.24,'PITCH/VOICED:','FontSize',10,'FontWeight','bold');
text(0.05,0.14,sprintf('%d bits total',total_bits),'FontSize',9);
text(0.05,0.04,'DSP COMPLETE','FontSize',10,'FontWeight','bold','Color',[0 0.7 0]); axis off;

sgtitle('EE3001 TELECOM PROJECT - COMPLETE DSP PIPELINE','FontSize',14,'FontWeight','bold');

fprintf('\n');
fprintf('TABLE 1: DATA SIZE\n');
fprintf('┌─────────────────────────────┬────────────┬────────────────┐\n');
fprintf('│ Stage                       │ Size (KB)  │ Compression    │\n');
fprintf('├─────────────────────────────┼────────────┼────────────────┤\n');
fprintf('│ Original (48 kHz corrupted) │ %10.2f │ 1:1 (baseline) │\n', bytes_original/1024);
fprintf('│ Downsampled (8 kHz)         │ %10.2f │ 1:%-11.0f │\n', bytes_8k/1024, bytes_original/bytes_8k);
fprintf('│ Binary (LSF+Gain+Pitch+VUV) │ %10.3f │ 1:%-11.0f │\n', total_bytes/1024, bytes_original/total_bytes);
fprintf('└─────────────────────────────┴────────────┴────────────────┘\n\n');

fprintf('TABLE 2: VOCODER QUALITY\n');
fprintf('┌──────────────────┬────────────┬──────────┐\n');
fprintf('│ Vocoder Type     │ Corr.      │ SNR (dB) │\n');
fprintf('├──────────────────┼────────────┼──────────┤\n');
fprintf('│ Residual-based   │ %10.4f │ %8.2f │\n', cc_res(1,2), snr_res);
fprintf('│ Parametric       │ %10.4f │ %8.2f │\n', cc_par(1,2), snr_par);
fprintf('└──────────────────┴────────────┴──────────┘\n\n');

fprintf('TABLE 3: QUANTIZATION\n');
fprintf('┌──────────────────────┬──────┬────────────────┬───────────┐\n');
fprintf('│ Parameter            │ Bits │ Range          │ Levels    │\n');
fprintf('├──────────────────────┼──────┼────────────────┼───────────┤\n');
fprintf('│ LSF (x%d coef.)     │  %2d  │ 0 - pi rad     │ 256       │\n', lpc_order, lsf_bits);
fprintf('│ Gain                 │  %2d  │ %.1f-%.1f dB  │ 256       │\n', gain_bits, gain_db_min, gain_db_max);
fprintf('│ Pitch                │  %2d  │ %d-%d Hz       │ 128       │\n', pitch_bits, min_pitch, max_pitch);
fprintf('│ Voiced/Unvoiced      │   1  │ Binary         │ 2         │\n');
fprintf('│ TOTAL per frame      │ %3d  │                │           │\n', bits_per_frame);
fprintf('└──────────────────────┴──────┴────────────────┴───────────┘\n\n');

fprintf('════════════════════════════════════════════════════════════════════\n');
fprintf('                  DSP PART 1 COMPLETED!\n');
fprintf('════════════════════════════════════════════════════════════════════\n\n');

%% ========================================================================
%% PART 2: BPSK - MODULATION, USRP TX/RX, DEMODULATION
%% ========================================================================

fprintf('\n════════════════════════════════════════════════════════════════════\n');
fprintf('  PART 2: BPSK - USRP TX/RX\n');
fprintf('════════════════════════════════════════════════════════════════════\n\n');

fprintf('STEP: BPSK MODULATION PARAMETERS\n');
fprintf('────────────────────────────────────────────────────────────────────\n\n');

symbol_rate        = 4000;
samples_per_symbol = 10;
Fs_baseband        = symbol_rate * samples_per_symbol;   % 40 kHz
Fs_usrp            = 200e3;
carrier_freq_usrp  = 433e6;   % 400 MHz antenna band
tx_gain            = 30;
rx_gain            = 25;
rolloff            = 0.5;
filter_span        = 6;
rrc_filter         = rcosdesign(rolloff, filter_span, samples_per_symbol, 'sqrt');
rrc_delay          = (length(rrc_filter) - 1) / 2;

rng(1);
preamble_bits = randi([0 1], 64, 1);
preamble_len  = length(preamble_bits);

% Convert binary data to a frame matrix
binary_frames = reshape(binary_data, bits_per_frame, num_frames);
%% ========================================================================
%% OPTIONAL ECC: HAMMING(7,4)
%% ========================================================================

use_ecc = true;              % Set false to disable ECC
use_interleaving = true;     % Set false to disable interleaving
ecc_name = 'Hamming(7,4)';

interleaver_rows = 14;       % 14 x 14 = 196 bits
interleaver_cols = 14;

if use_ecc
    coded_bits_per_frame = bits_per_frame/4 * 7;
    coded_binary_frames = zeros(coded_bits_per_frame, num_frames);

    for fi = 1:num_frames
        coded_binary_frames(:,fi) = hamming74_encode(binary_frames(:,fi));
    end

    fprintf('ECC ENABLED: %s\n', ecc_name);
    fprintf('  Original payload : %d bits/frame\n', bits_per_frame);
    fprintf('  Coded payload    : %d bits/frame\n', coded_bits_per_frame);
    fprintf('  ECC overhead     : %.1f%%\n', ...
        (coded_bits_per_frame/bits_per_frame - 1)*100);
else
    coded_binary_frames = binary_frames;
    coded_bits_per_frame = bits_per_frame;

    fprintf('ECC DISABLED\n');
    fprintf('  Payload: %d bits/frame\n', coded_bits_per_frame);
end

% Interleaving is applied after ECC encoding.
% It spreads adjacent channel errors over different Hamming blocks.
tx_payload_frames = zeros(coded_bits_per_frame, num_frames);

if use_interleaving
    if interleaver_rows * interleaver_cols ~= coded_bits_per_frame
        error('Interleaver size must match coded_bits_per_frame.');
    end

    for fi = 1:num_frames
        tx_payload_frames(:,fi) = block_interleave(coded_binary_frames(:,fi), ...
            interleaver_rows, interleaver_cols);
    end

    fprintf('INTERLEAVING ENABLED: Block interleaver %d x %d\n\n', ...
        interleaver_rows, interleaver_cols);
else
    tx_payload_frames = coded_binary_frames;
    fprintf('INTERLEAVING DISABLED\n\n');
end

fprintf('PACKETIZATION STRATEGY:\n');
fprintf('  Total frames:      %d\n', num_frames);
fprintf('  Source bits/frame: %d\n', bits_per_frame);
fprintf('  TX bits/frame:     %d\n', coded_bits_per_frame);
fprintf('  Preamble:          %d bits\n', preamble_len);
fprintf('  Packet size:       %d bits\n\n', preamble_len + coded_bits_per_frame);

fprintf('MODULATION PARAMETERS:\n');
fprintf('  Symbol rate:   %d bps\n', symbol_rate);
fprintf('  Smp/Symbol:    %d\n', samples_per_symbol);
fprintf('  Baseband Fs:   %.1f kHz\n', Fs_baseband/1000);
fprintf('  USRP Fs:       %.0f kHz\n', Fs_usrp/1000);
fprintf('  RF Carrier:    %.1f MHz\n', carrier_freq_usrp/1e6);
fprintf('  TX Gain:       %d dB\n', tx_gain);
fprintf('  RX Gain:       %d dB\n\n', rx_gain);

%% BPSK Proof Figures

fprintf('Generating BPSK proof figures...\n');

proof_bits    = [preamble_bits; binary_frames(:,1)];
num_bits_plot = 12;
example_bits  = proof_bits(1:num_bits_plot);
example_syms  = 2*double(example_bits) - 1;

% Figure A: Bit to Symbol Mapping
figure('Name','BPSK Proof 1 - Bit to Symbol Mapping','Color','w','Position',[100 100 1200 500]);
subplot(2,1,1);
stairs(0:num_bits_plot-1,example_bits,'LineWidth',2); grid on;
ylim([-0.2 1.2]); xlim([0 num_bits_plot-1]); xlabel('Bit Index'); ylabel('Bit Value');
title('Original Binary Bits'); yticks([0 1]);
for k=1:num_bits_plot; text(k-1,example_bits(k)+0.08,num2str(example_bits(k)),'HorizontalAlignment','center','FontWeight','bold'); end
subplot(2,1,2);
stairs(0:num_bits_plot-1,example_syms,'LineWidth',2); grid on;
ylim([-1.5 1.5]); xlim([0 num_bits_plot-1]); xlabel('Symbol Index'); ylabel('BPSK Symbol');
title('BPSK Mapping: 0 \rightarrow -1, 1 \rightarrow +1'); yticks([-1 1]);
for k=1:num_bits_plot; text(k-1,example_syms(k)+0.12*sign(example_syms(k)),num2str(example_syms(k)),'HorizontalAlignment','center','FontWeight','bold'); end

% Figure B: Ideal Constellation
figure('Name','BPSK Proof 2 - Ideal BPSK Constellation','Color','w','Position',[150 150 700 600]);
scatter(real(example_syms),imag(example_syms),100,'filled'); hold on;
plot([-1 1],[0 0],'r*','MarkerSize',16,'LineWidth',2);
xline(0,'--k','Decision Boundary'); yline(0,'--k');
grid on; axis equal; xlim([-1.5 1.5]); ylim([-1.5 1.5]);
xlabel('In-Phase'); ylabel('Quadrature');
title('Ideal BPSK Constellation: Two Symbols on Real Axis');
legend('Mapped Symbols','Ideal BPSK Points','Location','best');

% Figure C: Passband Phase Reversal
phase_bits = [0 1 0 1 1 0 0 1 0 1 1 0].';
phase_syms = 2*double(phase_bits) - 1;
Tb = 1/symbol_rate; Ns_plot = 200;
m_t    = repelem(phase_syms, Ns_plot, 1);
t_phase = (0:length(m_t)-1).' * (Tb/Ns_plot);
fc_plot = 4/Tb;
c_t    = cos(2*pi*fc_plot*t_phase);
u_t    = m_t .* c_t;

figure('Name','BPSK Proof 3 - Phase Reversal','Color','w','Position',[100 100 1300 750]);
subplot(2,1,1); plot(t_phase*1000,m_t,'LineWidth',2); grid on; ylim([-1.5 1.5]); xlim([0 max(t_phase)*1000]);
ylabel('m(t)'); title('Bipolar Message m(t): 0 \rightarrow -1, 1 \rightarrow +1');
for k=0:length(phase_bits); xline(k*Tb*1000,'--k'); end
subplot(2,1,2); plot(t_phase*1000,c_t,'LineWidth',1.3); grid on; ylim([-1.5 1.5]); xlim([0 max(t_phase)*1000]);
ylabel('c(t)'); title('Reference Carrier c(t) = cos(2\pi f_c t)');
for k=0:length(phase_bits); xline(k*Tb*1000,'--k'); end


%% Prepare Packet Waveforms
fprintf('\nPreparing all packet waveforms...\n\n');

all_tx_waveforms = cell(num_frames, 1);
all_packet_bits  = cell(num_frames, 1);

for fi = 1:num_frames
    pkt_bits    = [preamble_bits; tx_payload_frames(:,fi)];
    all_packet_bits{fi} = pkt_bits;
    bpsk_syms   = 2*double(pkt_bits) - 1;
    tx_up       = upsample(bpsk_syms, samples_per_symbol);
    tx_full     = conv(tx_up, rrc_filter, 'full');
    tx_shp      = tx_full(rrc_delay+1 : end-rrc_delay);
    tx_shp      = tx_shp / max(abs(tx_shp)) * 0.9;
    tx_usrp_sig = resample(tx_shp, Fs_usrp, Fs_baseband);
    tx_usrp_sig = repmat(tx_usrp_sig, 5, 1);
    all_tx_waveforms{fi} = tx_usrp_sig;
    fprintf('  Packet %02d/%02d prepared (%d bits)\n', fi, num_frames, length(pkt_bits));
end
fprintf('\n  All %d packets prepared!\n', num_frames);

%% ========================================================================
%% TX BPSK SYMBOLS AND RRC BASEBAND SIGNAL
%% ========================================================================

% Use Packet 1 as example
tx_bits_example = all_packet_bits{1};
tx_syms_example = 2*double(tx_bits_example) - 1;

% RRC pulse-shaped baseband signal
tx_up_example   = upsample(tx_syms_example, samples_per_symbol);
tx_full_example = conv(tx_up_example, rrc_filter, 'full');
tx_rrc_example  = tx_full_example(rrc_delay+1 : end-rrc_delay);
tx_rrc_example  = tx_rrc_example / max(abs(tx_rrc_example));

% Show limited number of symbols/samples for clarity
n_sym_show = min(100, length(tx_syms_example));
n_samp_show = min(1000, length(tx_rrc_example));

figure('Name','TX BPSK Symbols and RRC Baseband Signal', ...
       'Color','w','Position',[100 100 1300 650]);

subplot(2,1,1);
stem(1:n_sym_show, tx_syms_example(1:n_sym_show), ...
    'filled','LineWidth',1.2);
xlabel('Symbol Index');
ylabel('Amplitude');
title('TX BPSK Symbols');
ylim([-1.2 1.2]);
grid on;

subplot(2,1,2);
plot(1:n_samp_show, real(tx_rrc_example(1:n_samp_show)), ...
    'LineWidth',1.2);
xlabel('Sample Index');
ylabel('Amplitude');
title('TX Baseband Signal After RRC Pulse Shaping (Normalized)');
ylim([-1.1 1.1]);
grid on;

sgtitle('Transmitted BPSK Signal Before USRP Transmission', ...
    'FontSize',13,'FontWeight','bold');

%% Full transmitted signal actually sent to USRP

tx_full_packet = all_tx_waveforms{1};
t_full_packet = (0:length(tx_full_packet)-1).' / Fs_usrp * 1000;

figure('Name','Full TX Signal Actually Sent to USRP','Color','w','Position',[100 100 1300 500]);

plot(t_full_packet, real(tx_full_packet),'LineWidth',1);
xlabel('Time (ms)');
ylabel('Amplitude');
title('Full Transmitted BPSK Waveform Actually Sent to USRP - Packet 1 Repeated 5 Times');
grid on;

% Figure D: Actual Pulse-Shaped Signal
tx_proof  = all_tx_waveforms{1};
ns_show_d = min(1500, length(tx_proof));
t_tx_prf  = (0:ns_show_d-1).' / Fs_usrp;
figure('Name','BPSK Proof 4 - Actual Baseband Signal to USRP','Color','w','Position',[200 200 1200 500]);
plot(t_tx_prf*1000,real(tx_proof(1:ns_show_d)),'LineWidth',1.2); grid on;
xlabel('Time (ms)'); ylabel('Amplitude'); title('Pulse-Shaped BPSK Baseband Signal Sent to USRP');

% Figure E: Pulse shaping + symbol sampling instants
prf_syms    = 2*double(all_packet_bits{1}) - 1;
tx_prf_up   = upsample(prf_syms, samples_per_symbol);
tx_prf_full = conv(tx_prf_up, rrc_filter, 'full');
tx_prf_shp  = tx_prf_full(rrc_delay+1 : end-rrc_delay);
tx_prf_shp  = tx_prf_shp / max(abs(tx_prf_shp)) * 0.9;
ns_sym_show = 20; ns_smp_show = ns_sym_show*samples_per_symbol;
tx_show     = tx_prf_shp(1:ns_smp_show);
t_show      = (0:ns_smp_show-1).' / Fs_baseband;
si_show     = 1:samples_per_symbol:ns_smp_show;

figure('Name','BPSK Proof 5 - Symbol Sampling Points','Color','w','Position',[200 200 1300 550]);
plot(t_show*1000,real(tx_show),'LineWidth',1.4); hold on;
stem(t_show(si_show)*1000,real(tx_show(si_show)),'filled','LineWidth',1.2);
grid on; xlabel('Time (ms)'); ylabel('Amplitude');
title('Pulse-Shaped BPSK Baseband Signal with Symbol Sampling Instants');
legend('Pulse-shaped BPSK waveform','Symbol sampling instants','Location','best');
for k=1:ns_sym_show
    text(t_show(si_show(k))*1000,real(tx_show(si_show(k)))+0.12, ...
        ['b=' num2str(prf_syms(k)>0) ',s=' num2str(prf_syms(k))], ...
        'HorizontalAlignment','center','FontSize',8,'FontWeight','bold');
end

%% Modulated Signal Visualization
fprintf('\nVisualizing the modulated signal...\n');

mod_syms    = 2*double(all_packet_bits{1}) - 1;
tx_up_mod   = upsample(mod_syms, samples_per_symbol);
tx_full_mod = conv(tx_up_mod, rrc_filter, 'full');
tx_bb_mod   = tx_full_mod(rrc_delay+1 : end-rrc_delay);
tx_bb_mod   = tx_bb_mod / max(abs(tx_bb_mod)) * 0.9;
tx_usrp_mod = resample(tx_bb_mod, Fs_usrp, Fs_baseband);

N_bb   = length(tx_bb_mod);
N_us   = length(tx_usrp_mod);
t_bb   = (0:N_bb-1).' / Fs_baseband * 1000;   % ms
t_us   = (0:N_us-1).' / Fs_usrp * 1000;

NFFT_bb = 2^nextpow2(N_bb);
BB_spec = fft(tx_bb_mod, NFFT_bb);
f_bb_ax = Fs_baseband/1000 * (0:NFFT_bb/2) / NFFT_bb;
BB_mag  = abs(BB_spec(1:NFFT_bb/2+1));

NFFT_us = 2^nextpow2(N_us);
US_spec = fft(tx_usrp_mod, NFFT_us);
f_us_ax = Fs_usrp/1000 * (0:NFFT_us/2) / NFFT_us;
US_mag  = abs(US_spec(1:NFFT_us/2+1));

eye_syms  = 3;
eye_samp  = eye_syms * samples_per_symbol;
eye_start = samples_per_symbol + 1;
eye_data  = tx_bb_mod(eye_start:end);

figure('Name','Modulated Signal','Color','w','Position',[100 80 1400 750]);

n_ms     = min(5, t_bb(end));
idx_5ms  = t_bb <= n_ms;
idx_5us  = t_us <= n_ms;

subplot(3,2,1);
plot(t_bb(idx_5ms),tx_bb_mod(idx_5ms),'b','LineWidth',1.4); hold on;
si_t = 1:samples_per_symbol:sum(idx_5ms);
stem(t_bb(si_t),tx_bb_mod(si_t),'r','filled','LineWidth',1,'MarkerSize',4);
xlabel('Time (ms)'); ylabel('Amplitude');
title(sprintf('Baseband BPSK – Time (%d kHz)',Fs_baseband/1000),'FontWeight','bold');
legend('Shaped waveform','Sampling instants','Location','best'); grid on;

subplot(3,2,2);
plot(t_us(idx_5us),tx_usrp_mod(idx_5us),'Color',[0.1 0.6 0.1],'LineWidth',1.2);
xlabel('Time (ms)'); ylabel('Amplitude');
title(sprintf('USRP Waveform – Time (%d kHz)',Fs_usrp/1000),'FontWeight','bold'); grid on;

subplot(3,2,3);
plot(f_bb_ax,20*log10(BB_mag+eps),'b','LineWidth',1.5);
xline(symbol_rate/1000*(1+rolloff)/2,'r--','LineWidth',1.5,'Label','BW limit');
xlabel('Frequency (kHz)'); ylabel('Magnitude (dB)');
title('Baseband Spektrum','FontWeight','bold'); grid on; xlim([0 Fs_baseband/1000/2]);

subplot(3,2,4);
plot(f_us_ax,20*log10(US_mag+eps),'Color',[0.1 0.6 0.1],'LineWidth',1.5);
xlabel('Frequency (kHz)'); ylabel('Magnitude (dB)');
title(sprintf('USRP Output Spectrum (%d kHz sampling)',Fs_usrp/1000),'FontWeight','bold');
grid on; xlim([0 Fs_usrp/1000/2]);

subplot(3,2,5); hold on;
col = lines(8); num_traces = 0; k_eye = 1;
while k_eye+eye_samp-1 <= length(eye_data) && num_traces < 80
    seg   = eye_data(k_eye:k_eye+eye_samp-1);
    t_eye = (0:eye_samp-1)/Fs_baseband*1000;
    plot(t_eye,seg,'Color',[col(mod(num_traces,8)+1,:) 0.35],'LineWidth',0.8);
    k_eye = k_eye + samples_per_symbol; num_traces = num_traces+1;
end
xline((0:eye_syms)*samples_per_symbol/Fs_baseband*1000,'--k','Alpha',0.3);
xlabel('Time (ms)'); ylabel('Amplitude');
title(sprintf('Eye Diagram (%d symbols / window)',eye_syms),'FontWeight','bold');
grid on; ylim([-1.2 1.2]);

subplot(3,2,6);
[Pbb,Fbb] = pwelch(tx_bb_mod,hamming(256),128,512,Fs_baseband);
[Pus,Fus] = pwelch(tx_usrp_mod,hamming(256),128,512,Fs_usrp);
plot(Fbb/1000,10*log10(Pbb),'b','LineWidth',1.5,'DisplayName',sprintf('Baseband (%d kHz)',Fs_baseband/1000)); hold on;
plot(Fus/1000,10*log10(Pus),'Color',[0.1 0.6 0.1],'LineWidth',1.5,'DisplayName',sprintf('USRP (%d kHz)',Fs_usrp/1000));
xlabel('Frequency (kHz)'); ylabel('PSD (dB/Hz)');
title('Power Spectral Density','FontWeight','bold'); legend('Location','best'); grid on;

sgtitle(sprintf('BPSK Modulated Signal – Packet 1 | %d symbols | %d bps', ...
    length(mod_syms), symbol_rate),'FontSize',13,'FontWeight','bold');

fprintf('  Press ENTER to continue...\n'); pause;

%% USRP TX/RX
fprintf('\nSTEP: USRP TX/RX\n');
fprintf('────────────────────────────────────────────────────────────────────\n\n');

try
    tx_usrp_obj = comm.SDRuTransmitter(...
        'Platform', 'B200', ...
        'SerialNum', '31AE184', ...
        'CenterFrequency', carrier_freq_usrp, ...
        'Gain', tx_gain, ...
        'MasterClockRate', 20e6, ...
        'InterpolationFactor', round(20e6/Fs_usrp));
    fprintf('  USRP Transmitter ready (Gain: %d dB)\n', tx_gain);
catch ME
    error('USRP TX failed: %s', ME.message);
end

typical_packet_length = length(all_tx_waveforms{1});
rx_frame_len          = 2 * typical_packet_length;

try
    rx_usrp_obj = comm.SDRuReceiver(...
        'Platform', 'B200', ...
        'SerialNum', '31AE184', ...
        'CenterFrequency', carrier_freq_usrp, ...
        'Gain', rx_gain, ...
        'MasterClockRate', 20e6, ...
        'DecimationFactor', round(20e6/Fs_usrp), ...
        'SamplesPerFrame', rx_frame_len, ...
        'OutputDataType', 'double');
    fprintf('  USRP Receiver ready (Gain: %d dB)\n\n', rx_gain);
catch ME
    error('USRP RX failed: %s', ME.message);
end

all_rx_signals = cell(num_frames, 1);
all_rx_power   = zeros(num_frames, 1);

fprintf('Starting synchronized TX/RX for all packets...\n\n');
for fi = 1:num_frames
    tx_packet  = all_tx_waveforms{fi};
    num_trials = 5;
    rx_trials  = zeros(rx_frame_len, num_trials);
    trial_pwr  = zeros(num_trials, 1);
    for tr = 1:num_trials
        step(tx_usrp_obj, tx_packet);
        pkt_dur = length(tx_packet)/Fs_usrp;
        pause(pkt_dur + 0.01);
        temp_rx           = step(rx_usrp_obj);
        rx_trials(:,tr)   = temp_rx;
        trial_pwr(tr)     = mean(abs(temp_rx).^2);
    end
    [max_pwr, best_tr]      = max(trial_pwr);
    all_rx_signals{fi}      = rx_trials(:, best_tr);
    all_rx_power(fi)        = max_pwr;
    fprintf('  Packet %02d/%02d  power=%.4e\n', fi, num_frames, max_pwr);
end

release(tx_usrp_obj);
release(rx_usrp_obj);
fprintf('\n  USRP resources released\n\n');

%% ========================================================================
%% RECEIVED SIGNAL BEFORE DEMODULATION  (LabVIEW-equivalent view)
%% ========================================================================

fprintf('RECEIVED SIGNAL BEFORE DEMODULATION visualizing...\n');

% Use packet 1 as a representative example
ex_rx  = all_rx_signals{1};
ex_tx_raw = all_tx_waveforms{1};
n_compare  = min(length(ex_rx), length(ex_tx_raw));
ex_tx_show = ex_tx_raw(1:n_compare);

t_rx_ms    = (0:n_compare-1).' / Fs_usrp * 1000;   % ms
n_show_rx  = min(3000, n_compare);

% Spectrum
NFFT_rxv  = 2^nextpow2(n_compare);
TX_spec_v = fft(ex_tx_show,  NFFT_rxv);
RX_spec_v = fft(ex_rx(1:n_compare), NFFT_rxv);
f_rxv     = Fs_usrp/1000 * (0:NFFT_rxv/2) / NFFT_rxv;   % kHz

% Baseband conversion (before RRC)
rx_bb_preview = resample(ex_rx, Fs_baseband, Fs_usrp);
t_bb_prev     = (0:length(rx_bb_preview)-1).' / Fs_baseband * 1000;
n_bb_prev     = min(2000, length(rx_bb_preview));

figure('Name','RECEIVED SIGNAL Before Demodulation', ...
       'Position',[50 50 1450 720],'Color','w');

% TX I-component
subplot(3,2,1);
plot(t_rx_ms(1:n_show_rx), real(ex_tx_show(1:n_show_rx)),'b','LineWidth',1);
xlabel('Time (ms)'); ylabel('Amplitude');
title('TX Baseband — In-Phase I (200 kHz, USRP input)','FontWeight','bold'); grid on;

% RX I-component
subplot(3,2,2);
plot(t_rx_ms(1:n_show_rx), real(ex_rx(1:n_show_rx)),'r','LineWidth',1);
xlabel('Time (ms)'); ylabel('Amplitude');
title(sprintf('RX Raw — In-Phase I (USRP output) | Relative Power=%.2e', ...
    mean(abs(ex_rx).^2)),'FontWeight','bold'); grid on;

% RX I and Q separately (also displayed this way in LabVIEW)
subplot(3,2,3);
plot(t_rx_ms(1:n_show_rx), real(ex_rx(1:n_show_rx)),'r','LineWidth',1); hold on;
plot(t_rx_ms(1:n_show_rx), imag(ex_rx(1:n_show_rx)),'m','LineWidth',1);
legend('I (In-Phase)','Q (Quadrature)','Location','best');
xlabel('Time (ms)'); ylabel('Amplitude');
title('RX Signal — I and Q Components Before Demodulation','FontWeight','bold'); grid on;

% TX vs RX spectrum comparison
subplot(3,2,4);
plot(f_rxv, 20*log10(abs(TX_spec_v(1:NFFT_rxv/2+1))+eps),'b','LineWidth',1.5,'DisplayName','TX'); hold on;
plot(f_rxv, 20*log10(abs(RX_spec_v(1:NFFT_rxv/2+1))+eps),'r','LineWidth',1.5,'DisplayName','RX (received)');
legend('Location','best'); xlabel('Frequency (kHz)'); ylabel('Magnitude (dB)');
title('Spectrum: TX vs RX — USRP Channel Effect','FontWeight','bold');
grid on; xlim([0 Fs_usrp/1000/2]);

% Baseband (resampled, before RRC)
subplot(3,2,5);
plot(t_bb_prev(1:n_bb_prev), real(rx_bb_preview(1:n_bb_prev)),'Color',[0.1 0.6 0.1],'LineWidth',1);
xlabel('Time (ms)'); ylabel('Amplitude');
title('RX After Resampling to Baseband (40 kHz) — Before RRC Match Filter','FontWeight','bold'); grid on;

% Received signal powers of all packets (relative link quality indicator)
subplot(3,2,6);

rx_pwr_dB = 10*log10(all_rx_power + eps);

plot(1:num_frames, rx_pwr_dB,'ro-', ...
    'LineWidth',1.5, ...
    'MarkerSize',6, ...
    'MarkerFaceColor','r');

yline(mean(rx_pwr_dB),'b--', ...
    'LineWidth',1.5, ...
    'Label',sprintf('Mean=%.1f dB',mean(rx_pwr_dB)));

xlabel('Packet Index');
ylabel('Relative Received Power (dB)');
title(sprintf('Relative RX Signal Power per Packet — %d packets total',num_frames), ...
    'FontWeight','bold');

grid on;

sgtitle('RECEIVED SIGNAL ANALYSIS — Before Demodulation (USRP RX Output)', ...
    'FontSize',13,'FontWeight','bold','Color',[0.8 0.1 0.1]);

fprintf('  Received signal figure generated.\n\n');

%% Demodulation
fprintf('STEP: DEMODULATION\n');
fprintf('────────────────────────────────────────────────────────────────────\n\n');

rx_frames                  = zeros(bits_per_frame, num_frames);          % decoded payload
rx_coded_frames            = zeros(coded_bits_per_frame, num_frames);    % received coded payload
packet_BER                 = zeros(num_frames, 1);                       % after ECC
packet_BER_raw             = zeros(num_frames, 1);                       % before ECC
packet_preamble_corr       = zeros(num_frames, 1);
best_rx_symbols_per_packet = cell(num_frames, 1);
frame_len                  = coded_bits_per_frame;

for fi = 1:num_frames
    fprintf('  Packet %02d/%02d... ', fi, num_frames);
    rx_sig    = all_rx_signals{fi};
    rx_bb     = resample(rx_sig, Fs_baseband, Fs_usrp);
    rx_ff     = conv(rx_bb, rrc_filter, 'full');
    rx_filt   = rx_ff(rrc_delay+1 : end-rrc_delay);

    best_metric = -inf; best_rx_frame = []; best_corr = -inf; best_rx_symbols = [];

    for offset = 1:samples_per_symbol
        temp_syms = rx_filt(offset:samples_per_symbol:end);
        if length(temp_syms) < preamble_len + frame_len; continue; end
        temp_norm = temp_syms / (max(abs(temp_syms)) + eps);

        bits_cands = {double(real(temp_norm)>0); double(real(temp_norm)<0);
                      double(imag(temp_norm)>0); double(imag(temp_norm)<0)};

        for ax = 1:4
            tb = bits_cands{ax};
            if length(tb) < preamble_len + frame_len; continue; end
            rx_bip  = 2*tb - 1;
            pr_bip  = 2*preamble_bits - 1;
            pr_corr = conv(rx_bip, flipud(pr_bip), 'valid');
            [mc, pi_] = max(pr_corr);
            pe = pi_ + preamble_len - 1;
            if pe <= length(temp_syms)
                rx_pre = temp_syms(pi_:pe);
                tx_pre = 2*double(preamble_bits) - 1;
                h_est  = sum(rx_pre.*conj(tx_pre)) / sum(abs(tx_pre).^2);
                syms_eq  = temp_syms / (h_est + eps);
                syms_en  = syms_eq / (max(abs(syms_eq)) + eps);
                eq_cands = {double(real(syms_en)>0); double(real(syms_en)<0);
                            double(imag(syms_en)>0); double(imag(syms_en)<0)};
                for eq = 1:4
                    tb_eq = eq_cands{eq};
                    fs = pi_ + preamble_len; fe = fs + frame_len - 1;
                    if fe <= length(tb_eq) && mc > best_metric
                        best_metric   = mc;
                        best_rx_frame = tb_eq(fs:fe);
                        best_corr     = mc;
                        best_rx_symbols = syms_eq(pi_:fe);
                    end
                end
            end
        end
    end

    if ~isempty(best_rx_frame)

        % Store received payload in transmitted order
        rx_coded_frames(:,fi) = best_rx_frame;

        % Raw BER before deinterleaving/ECC correction.
        % Compare with tx_payload_frames because this is the actual transmitted payload.
        packet_BER_raw(fi) = sum(tx_payload_frames(:,fi) ~= best_rx_frame) / coded_bits_per_frame;

        % Deinterleaving before ECC decoding
        if use_interleaving
            rx_deinterleaved = block_deinterleave(best_rx_frame, ...
                interleaver_rows, interleaver_cols);
        else
            rx_deinterleaved = best_rx_frame;
        end

        % ECC decoding
        if use_ecc
            decoded_payload = hamming74_decode(rx_deinterleaved);
        else
            decoded_payload = rx_deinterleaved;
        end

        % Store decoded original payload
        rx_frames(:,fi) = decoded_payload;
    
        % BER after ECC correction
        packet_BER(fi) = sum(binary_frames(:,fi) ~= decoded_payload) / bits_per_frame;
    
        packet_preamble_corr(fi)       = best_corr;
        best_rx_symbols_per_packet{fi} = best_rx_symbols;
    
        fprintf('Raw BER=%.4f, Post-ECC BER=%.4f, Preamble=%.1f/%d\n', ...
            packet_BER_raw(fi), packet_BER(fi), best_corr, preamble_len);
    
    else
        packet_BER_raw(fi) = 1.0;
        packet_BER(fi) = 1.0;
        fprintf('FAILED\n');
    end
end

rx_bits     = rx_frames(:);
bit_errors  = sum(binary_data ~= rx_bits);
overall_BER = bit_errors / length(binary_data);

fprintf('\nOVERALL BIT ERROR ANALYSIS:\n');
fprintf('  Total bits:    %d\n', length(binary_data));
fprintf('  Bit errors:    %d\n', bit_errors);
fprintf('  Overall BER:   %.6f\n', overall_BER);
fprintf('  Bit accuracy:  %.4f%%\n', (1-overall_BER)*100);
fprintf('  Perfect pkts:  %d / %d\n', sum(packet_BER==0), num_frames);

%% ========================================================================
%% RECEIVER DEBUG VIEW: RX SIGNAL, HARD BITS, PREAMBLE SCORES
%% ========================================================================

% Concatenate received USRP signals from all packets
rx_all_concat = [];
for fi = 1:num_frames
    rx_all_concat = [rx_all_concat; all_rx_signals{fi}(:)];
end

% First recovered hard bits before deinterleaving and ECC
first_hard_bits = rx_coded_frames(:);
n_bits_show = min(200, length(first_hard_bits));

figure('Name','Receiver Debug View - RX Signal, Hard Bits, Preamble Score', ...
       'Color','w','Position',[80 80 1300 850]);

% 1) Full received signal
subplot(4,1,1);
plot(real(rx_all_concat),'LineWidth',1);
xlabel('Sample Index');
ylabel('Amplitude');
title('Received Signal - Real Part (Full View)');
grid on;

% 2) Zoomed received signal
[~, peak_idx] = max(abs(rx_all_concat));
zoom_half = 1200;

z1 = max(1, peak_idx - zoom_half);
z2 = min(length(rx_all_concat), peak_idx + zoom_half);

subplot(4,1,2);
plot(z1:z2, real(rx_all_concat(z1:z2)), 'LineWidth',1.2);
xlabel('Sample Index');
ylabel('Amplitude');
title('Received Signal - Real Part (Zoomed View)');
grid on;

% 3) First recovered hard bits
subplot(4,1,3);
stem(0:n_bits_show-1, first_hard_bits(1:n_bits_show), ...
    'filled','LineWidth',1);
xlabel('Bit Index');
ylabel('Bit');
title('First Recovered Hard Bits');
ylim([-0.2 1.2]);
grid on;

% 4) Best preamble score per frame
subplot(4,1,4);
bar(1:num_frames, packet_preamble_corr);
xlabel('Frame Index');
ylabel('Preamble Score');
title('Best Preamble Score per Frame');
ylim([0 preamble_len]);
grid on;

sgtitle('Receiver Debug View: USRP RX Signal, Hard Bits, and Preamble Sync', ...
    'FontSize',13,'FontWeight','bold');

figure('Name','ECC Performance - Raw BER vs Post-ECC BER','Color','w','Position',[100 100 1100 600]);

subplot(2,1,1);
stem(1:num_frames, packet_BER_raw, 'filled','LineWidth',1.2);
xlabel('Packet Index');
ylabel('Raw BER');
title('BER Before ECC Correction');
grid on;
ylim([0 max(0.1, max(packet_BER_raw)+0.05)]);

subplot(2,1,2);
stem(1:num_frames, packet_BER, 'filled','LineWidth',1.2);
xlabel('Packet Index');
ylabel('Post-ECC BER');
title('BER After Deinterleaving + Hamming(7,4) ECC Correction');
grid on;
ylim([0 max(0.1, max(packet_BER)+0.05)]);

sgtitle('ECC Bonus: Hamming(7,4) + Interleaving Performance', ...
    'FontSize',13,'FontWeight','bold');

fprintf('\nECC PERFORMANCE:\n');
fprintf('  Raw BER before ECC : %.6f\n', mean(packet_BER_raw));
fprintf('  BER after ECC      : %.6f\n', mean(packet_BER));
fprintf('  Corrected bit errors approximately: %d -> %d\n\n', ...
    round(mean(packet_BER_raw)*coded_bits_per_frame*num_frames), bit_errors);

%% ========================================================================
%% EVM AND ESTIMATED SNR FROM EQUALIZED CONSTELLATION
%% ========================================================================

evm_per_packet     = zeros(num_frames,1);
snr_evm_packet     = zeros(num_frames,1);

for p = 1:num_frames
    sy = best_rx_symbols_per_packet{p};

    if isempty(sy)
        evm_per_packet(p) = NaN;
        snr_evm_packet(p) = NaN;
        continue;
    end

    sy = sy(:);
    sy_rms = sqrt(mean(abs(sy).^2));
    sy = sy / (sy_rms + eps);

    % Decision points for BPSK: -1 or +1 on the real axis
    decided = 2*double(real(sy) > 0) - 1;

    % Error vector between equalized received symbols and ideal decisions
    err = sy - decided;

    evm_per_packet(p) = sqrt(mean(abs(err).^2) / mean(abs(decided).^2));
    snr_evm_packet(p) = -20*log10(evm_per_packet(p) + eps);
end

fprintf('\nEVM / ESTIMATED SNR ANALYSIS:\n');
fprintf('  Mean EVM       : %.2f %%\n', mean(evm_per_packet,'omitnan')*100);
fprintf('  Mean SNR(EVM)  : %.2f dB\n', mean(snr_evm_packet,'omitnan'));
fprintf('  Best SNR(EVM)  : %.2f dB\n', max(snr_evm_packet));
fprintf('  Worst SNR(EVM) : %.2f dB\n\n', min(snr_evm_packet));

figure('Name','EVM and Estimated SNR from Equalized Constellation','Color','w','Position',[100 100 1100 600]);

subplot(2,1,1);
plot(1:num_frames, evm_per_packet*100, 'o-','LineWidth',1.5,'MarkerSize',6);
xlabel('Packet Index');
ylabel('EVM (%)');
title('EVM per Packet');
grid on;

subplot(2,1,2);
plot(1:num_frames, snr_evm_packet, 'o-','LineWidth',1.5,'MarkerSize',6);
xlabel('Packet Index');
ylabel('Estimated SNR (dB)');
title('Estimated SNR from Equalized BPSK Constellation');
grid on;

sgtitle('Modulation Performance: EVM and Estimated SNR','FontSize',13,'FontWeight','bold');

%% ========================================================================
%% TOTAL REAL USRP LINK QUALITY FIGURE
%% ========================================================================

rx_power_dB = 10*log10(all_rx_power + eps);

figure('Name','Total Real USRP Link Quality Summary', ...
       'Color','w','Position',[80 60 1400 850]);

subplot(3,2,1);
stem(1:num_frames, packet_BER_raw, 'filled','LineWidth',1.2);
xlabel('Packet Index');
ylabel('Raw BER');
title('Raw BER Before ECC');
grid on;
ylim([0 max(0.02, max(packet_BER_raw)+0.005)]);

subplot(3,2,2);
stem(1:num_frames, packet_BER, 'filled','LineWidth',1.2);
xlabel('Packet Index');
ylabel('Post-ECC BER');
title('Post-ECC BER After Deinterleaving + Hamming(7,4)');
grid on;
ylim([0 max(0.02, max(packet_BER)+0.005)]);

subplot(3,2,3);
plot(1:num_frames, evm_per_packet*100, 'o-','LineWidth',1.5,'MarkerSize',6);
xlabel('Packet Index');
ylabel('EVM (%)');
title(sprintf('EVM per Packet | Mean = %.2f%%', mean(evm_per_packet,'omitnan')*100));
grid on;

subplot(3,2,4);
plot(1:num_frames, snr_evm_packet, 'o-','LineWidth',1.5,'MarkerSize',6);
xlabel('Packet Index');
ylabel('Estimated SNR (dB)');
title(sprintf('Estimated Communication SNR | Mean = %.2f dB', ...
    mean(snr_evm_packet,'omitnan')));
grid on;

subplot(3,2,5);
plot(1:num_frames, packet_preamble_corr, 's-','LineWidth',1.5,'MarkerSize',6);
xlabel('Packet Index');
ylabel('Preamble Correlation');
title('Preamble Synchronization Score');
grid on;
ylim([0 preamble_len]);

subplot(3,2,6);
plot(1:num_frames, rx_power_dB, 'o-','LineWidth',1.5,'MarkerSize',6);
xlabel('Packet Index');
ylabel('Relative RX Power (dB)');
title(sprintf('Relative RX Power | Mean = %.1f dB', mean(rx_power_dB)));
grid on;

sgtitle(sprintf(['Total Real USRP Link Quality | Raw BER = %.6f | ', ...
    'Post-ECC BER = %.6f | Mean SNR(EVM) = %.2f dB'], ...
    mean(packet_BER_raw), overall_BER, mean(snr_evm_packet,'omitnan')), ...
    'FontSize',13,'FontWeight','bold');

if overall_BER == 0
    fprintf('\n  POST-ECC ZERO BIT ERRORS!\n');
elseif overall_BER < 0.01
    fprintf('\n  Excellent! Post-ECC BER < 1%%\n');
elseif overall_BER < 0.05
    fprintf('\n  Good! Post-ECC BER < 5%%\n');
else
    fprintf('\n  Post-ECC BER still elevated\n');
end

% Visualization: TX waveform
example_packet = 1;
tx_example = all_tx_waveforms{example_packet};
t_tx = (0:length(tx_example)-1)/Fs_usrp;
figure('Name','Transmitted BPSK Waveform','Color','w');
plot(t_tx(1:min(1000,end))*1000, real(tx_example(1:min(1000,end))),'LineWidth',1.2);
xlabel('Time (ms)'); ylabel('Amplitude');
title(sprintf('Transmitted BPSK Baseband Waveform - Packet %d',example_packet)); grid on;

%% Combined RX Constellation for All Packets

all_rx_syms_combined = [];

for p = 1:num_frames
    sy = best_rx_symbols_per_packet{p};

    if ~isempty(sy)
        sy = sy(:);
        sy = sy / (max(abs(sy)) + eps);
        all_rx_syms_combined = [all_rx_syms_combined; sy];
    end
end

figure('Name','Combined RX BPSK Constellation','Color','w','Position',[100 100 700 600]);

scatter(real(all_rx_syms_combined), imag(all_rx_syms_combined), ...
    12, 'filled', 'MarkerFaceAlpha', 0.35);
hold on;

plot([-1 1], [0 0], 'r*', 'MarkerSize', 16, 'LineWidth', 2);
xline(0,'--k','Decision Boundary');
yline(0,'--k');

grid on;
axis equal;
xlim([-1.5 1.5]);
ylim([-1.5 1.5]);

xlabel('In-Phase');
ylabel('Quadrature');
title(sprintf('Combined RX BPSK Constellation - All Packets | Overall BER = %.4f', overall_BER), ...
    'FontWeight','bold');

legend('Equalized RX Symbols','Ideal BPSK Points','Location','best');

% Visualization: Equalized Constellation Diagrams
error_packets  = find(packet_BER > 0);
perfect_packets = find(packet_BER == 0);
pkt_error   = 1; if ~isempty(error_packets);   pkt_error   = error_packets(1);   end
pkt_perfect = 1; if ~isempty(perfect_packets);  pkt_perfect = perfect_packets(1); end
packet_indices = unique([1, pkt_error, pkt_perfect, num_frames],'stable');
while length(packet_indices) < 4
    c = randi(num_frames);
    if ~ismember(c, packet_indices); packet_indices(end+1) = c; end
end
packet_indices = packet_indices(1:4);

figure('Name','Equalized BPSK Constellation Diagrams','Position',[100 100 1400 500],'Color','w');
for i = 1:4
    subplot(1,4,i);
    pidx = packet_indices(i);
    if ~isempty(best_rx_symbols_per_packet{pidx})
        syms_n = best_rx_symbols_per_packet{pidx};
        syms_n = syms_n / (max(abs(syms_n))+eps);
        scatter(real(syms_n),imag(syms_n),18,'filled','MarkerFaceAlpha',0.6); hold on;
        plot([-1 1],[0 0],'r*','MarkerSize',14,'LineWidth',2);
        xline(0,'--k'); xlabel('In-Phase'); ylabel('Quadrature');
        title(sprintf('Packet %d | BER=%.4f',pidx,packet_BER(pidx)),'FontSize',11,'FontWeight','bold');
        grid on; axis equal; xlim([-1.5 1.5]); ylim([-1.5 1.5]);
        legend('Equalized RX','Ideal BPSK','Location','best','FontSize',7);
    else
        title(sprintf('Packet %d | No symbols',pidx)); grid on;
    end
end
sgtitle('Equalized BPSK Constellation - Preamble-Based Sync','FontSize',13,'FontWeight','bold');

% Visualization: Received power per packet
figure('Name','Received Power per Packet','Color','w');
plot(1:num_frames,10*log10(all_rx_power+eps),'o-','LineWidth',1.5,'MarkerSize',6);
xlabel('Packet / Frame Index'); ylabel('Received Power (dB)');
title('Received Signal Power per Packet'); grid on;

% Visualization: BER and preamble summary
figure('Name','Packet Performance Summary','Color','w');
subplot(3,1,1);
stem(1:num_frames,packet_BER,'filled','LineWidth',1.2);
xlabel('Packet / Frame Index'); ylabel('BER'); title('BER per Packet');
grid on; ylim([0 max(0.1,max(packet_BER)+0.05)]);
subplot(3,1,2);
plot(1:num_frames,packet_preamble_corr,'s-','LineWidth',1.5,'MarkerSize',6);
xlabel('Packet / Frame Index'); ylabel('Correlation');
title('Preamble Correlation per Packet'); grid on; ylim([0 preamble_len]);
subplot(3,1,3);
bar([mean(packet_BER),median(packet_BER),min(packet_BER),max(packet_BER)]);
set(gca,'XTickLabel',{'Mean','Median','Best','Worst'}); ylabel('BER'); title('BER Statistics'); grid on;

% Visualization: Bit error location map
bit_error_map = binary_data ~= rx_bits;
figure('Name','Bit Error Location Map','Color','w');
stem(find(bit_error_map),ones(sum(bit_error_map),1),'filled');
xlabel('Bit Index'); ylabel('Error');
title(sprintf('Bit Error Locations - Total=%d, BER=%.4e',bit_errors,overall_BER));
grid on; ylim([0 1.2]);
xlim([1 length(binary_data)]);

fprintf('\n════════════════════════════════════════════════════════════════════\n');
fprintf('              BPSK PART 2 COMPLETED!\n');
fprintf('════════════════════════════════════════════════════════════════════\n\n');

%% ========================================================================
%% PART 3: SPEECH SYNTHESIS FROM RECEIVED BITS
%% ========================================================================

fprintf('\n════════════════════════════════════════════════════════════════════\n');
fprintf('  PART 3: SPEECH SYNTHESIS FROM RECEIVED BITS\n');
fprintf('════════════════════════════════════════════════════════════════════\n\n');

fprintf('STEP: BIT DECODING - LSF / GAIN / PITCH / VOICED\n');
fprintf('────────────────────────────────────────────────────────────────────\n\n');

% rx_frames is already in the (bits_per_frame x num_frames) matrix
lsf_decoded    = zeros(num_frames, lpc_order);
gain_decoded   = zeros(num_frames, 1);
pitch_decoded  = zeros(num_frames, 1);
voiced_decoded = zeros(num_frames, 1);
lpc_decoded    = zeros(num_frames, lpc_order+1);

fprintf('  Decoding %d frames...\n', num_frames);

for i = 1:num_frames
    frame_bits = rx_frames(:, i);
    bit_ptr    = 1;

    % LSF
    for j = 1:lpc_order
        bits_lsf = frame_bits(bit_ptr : bit_ptr+lsf_bits-1)';
        lsf_decoded(i,j) = (bi2de(bits_lsf,'left-msb') / (2^lsf_bits-1)) * pi;
        bit_ptr = bit_ptr + lsf_bits;
    end
    % Gain
    bits_g = frame_bits(bit_ptr : bit_ptr+gain_bits-1)';
    gain_decoded(i) = gain_db_min + (bi2de(bits_g,'left-msb')/(2^gain_bits-1)) * gain_db_range;
    bit_ptr = bit_ptr + gain_bits;
    % Pitch
    bits_p = frame_bits(bit_ptr : bit_ptr+pitch_bits-1)';
    pitch_decoded(i) = min_pitch + (bi2de(bits_p,'left-msb')/(2^pitch_bits-1)) * (max_pitch-min_pitch);
    bit_ptr = bit_ptr + pitch_bits;
    % Voiced
    voiced_decoded(i) = frame_bits(bit_ptr);

    % LSF -> LPC (stability enforcement)
    lsf_row = sort(lsf_decoded(i,:));
    lsf_row = max(1e-4, min(pi-1e-4, lsf_row));
    for k = 2:lpc_order
        if lsf_row(k)-lsf_row(k-1) < 1e-3; lsf_row(k) = lsf_row(k-1)+1e-3; end
    end
    lsf_row = min(pi-1e-4, lsf_row);
    lsf_decoded(i,:) = lsf_row;
    try
        lpc_decoded(i,:) = lsf2poly(lsf_row);
    catch
        lpc_decoded(i,:) = [1 zeros(1,lpc_order)];
    end
end

fprintf('  Decoding completed!\n\n');

voiced_frames_dec = sum(voiced_decoded);
voiced_pitch_dec  = pitch_decoded(voiced_decoded == 1);
fprintf('  Voiced: %d / %d frames\n', voiced_frames_dec, num_frames);
if ~isempty(voiced_pitch_dec)
    fprintf('  Pitch: %.1f Hz avg (%.1f - %.1f Hz)\n', mean(voiced_pitch_dec), min(voiced_pitch_dec), max(voiced_pitch_dec));
end
fprintf('  Gain avg: %.1f dB\n\n', mean(gain_decoded));

fprintf('STEP: PARAMETRIC VOCODER SYNTHESIS\n');
fprintf('────────────────────────────────────────────────────────────────────\n\n');

total_samples = frame_shift_samples*(num_frames-1) + frame_length_samples;
x_synth       = zeros(total_samples, 1);
overlap_syn   = zeros(total_samples, 1);

fprintf('  Synthesizing %d frames (%.3f s)...\n', num_frames, total_samples/Fs_target);

for i = 1:num_frames
    s_idx = (i-1)*frame_shift_samples + 1;
    e_idx = s_idx + frame_length_samples - 1;
    if e_idx > total_samples; break; end
    a = lpc_decoded(i,:);
    if voiced_decoded(i) && pitch_decoded(i) > 0
        pp  = max(1, round(Fs_target/pitch_decoded(i)));
        exc = zeros(frame_length_samples, 1);
        exc(1:pp:end) = 1;
    else
        exc = randn(frame_length_samples, 1);
    end
    sf        = filter(1, a, exc);
    tgt_rms   = 10^(gain_decoded(i)/20) * 1e-3;
    sf_rms    = sqrt(mean(sf.^2));
    if sf_rms > eps; sf = sf*(tgt_rms/sf_rms); end
    sf_w = sf .* win;
    x_synth(s_idx:e_idx)     = x_synth(s_idx:e_idx)     + sf_w;
    overlap_syn(s_idx:e_idx) = overlap_syn(s_idx:e_idx) + win;
    if mod(i,10)==0; fprintf('  Frame %d/%d\n',i,num_frames); end
end
overlap_syn(overlap_syn < 0.01) = 1;
x_synth = x_synth ./ overlap_syn;
pk = max(abs(x_synth));
if pk > eps; x_synth = x_synth / pk * 0.95; end

fprintf('  Synthesis completed! (%d samples, %.3f s)\n\n', length(x_synth), length(x_synth)/Fs_target);

% Quality evaluation
min_len    = min(length(x_downsampled), length(x_synth));
orig_trim  = x_downsampled(1:min_len);
synth_trim = x_synth(1:min_len);
o_rms_q    = sqrt(mean(orig_trim.^2));
s_rms_q    = sqrt(mean(synth_trim.^2));
if s_rms_q > eps; synth_trim_norm = synth_trim*(o_rms_q/s_rms_q); else; synth_trim_norm = synth_trim; end
cc_synth   = corrcoef(orig_trim, synth_trim_norm);
corr_val   = cc_synth(1,2);
snr_val    = 10*log10(sum(orig_trim.^2) / (sum((orig_trim-synth_trim_norm).^2)+eps));

% Log Spectral Distance (LSD) — the correct metric for the parametric vocoder
n_lsd = min(num_frames, floor((length(x_synth)-frame_length_samples)/frame_shift_samples)+1);
lsd_vals = zeros(n_lsd, 1);
for i_lsd = 1:n_lsd
    so = (i_lsd-1)*frame_shift_samples+1; eo = so+frame_length_samples-1;
    ss = (i_lsd-1)*frame_shift_samples+1; es = ss+frame_length_samples-1;
    if eo>length(x_downsampled) || es>length(x_synth); break; end
    Po = abs(fft(x_downsampled(so:eo).*win, 512)).^2 + eps;
    Ps = abs(fft(x_synth(ss:es).*win, 512)).^2 + eps;
    lsd_vals(i_lsd) = sqrt(mean((10*log10(Po(1:256)) - 10*log10(Ps(1:256))).^2));
end
mean_lsd = mean(lsd_vals(lsd_vals > 0));

fprintf('QUALITY EVALUATION:\n');
fprintf('  Correlation (waveform) : %.4f\n', corr_val);
fprintf('  SNR (waveform)         : %.2f dB\n', snr_val);
fprintf('  Log Spectral Distance  : %.2f dB\n\n', mean_lsd);
fprintf('  NOTE: Waveform SNR/Corr is low by design for parametric vocoders.\n');
fprintf('  Parametric synthesis does NOT reproduce the waveform — only the\n');
fprintf('  Lower LSD means better spectral similarity.\n');
fprintf('  Current LSD = %.2f dB, so spectral match is limited/moderate.\n\n', mean_lsd);


% Visualization
t_synth    = (0:length(x_synth)-1) / Fs_target;
t_orig     = (0:length(x_downsampled)-1) / Fs_target;
t_frames_p3 = (0:num_frames-1)*frame_shift_samples/Fs_target;
lsf_hz_dec = lsf_decoded * Fs_target / (2*pi);

% Figure: Decoded Parameters
figure('Name','Decoded Speech Parameters','Position',[50 50 1400 700]);
subplot(2,3,1); plot(t_frames_p3,lsf_hz_dec,'LineWidth',1.5); xlabel('Time (s)'); ylabel('Freq (Hz)'); title('Decoded LSF'); grid on;
subplot(2,3,2); plot(t_frames_p3,gain_decoded,'r','LineWidth',1.5); xlabel('Time (s)'); ylabel('Gain (dB)'); title('Decoded Gain'); grid on;
subplot(2,3,3);
vi = find(voiced_decoded);
if ~isempty(vi); plot(t_frames_p3(vi),pitch_decoded(vi),'g.','MarkerSize',12); end
xlabel('Time (s)'); ylabel('Pitch (Hz)'); title('Decoded Pitch (Voiced)'); grid on; ylim([min_pitch-20, max_pitch+20]);
subplot(2,3,4); stairs(t_frames_p3,voiced_decoded,'b','LineWidth',1.5); xlabel('Time (s)'); title('Voiced/Unvoiced'); ylim([-0.2 1.2]); grid on;
subplot(2,3,5); imagesc(t_frames_p3,1:lpc_order,lsf_hz_dec'); colorbar; xlabel('Time (s)'); ylabel('LSF Index'); title('LSF Heat Map'); colormap(jet);
subplot(2,3,6);
text(0.05,0.95,'DECODE RESULTS','FontSize',12,'FontWeight','bold');
text(0.05,0.82,sprintf('Voiced: %d / %d frames',voiced_frames_dec,num_frames));
if ~isempty(voiced_pitch_dec); text(0.05,0.70,sprintf('Pitch avg: %.1f Hz',mean(voiced_pitch_dec))); end
text(0.05,0.58,sprintf('Gain avg: %.1f dB',mean(gain_decoded)));
text(0.05,0.44,'TRANSMISSION','FontSize',12,'FontWeight','bold');
text(0.05,0.32,sprintf('BER: %.6f',overall_BER));
text(0.05,0.20,sprintf('Bit errors: %d / %d',bit_errors,length(rx_bits)));
text(0.05,0.08,sprintf('SNR: %.2f dB | Corr: %.4f',snr_val,corr_val)); axis off;

% Figure: Signal Comparison
figure('Name','Synthesized Speech Comparison','Position',[50 50 1400 800]);
subplot(3,2,1); plot(t_orig,x_downsampled,'b','LineWidth',0.7); xlabel('Time (s)'); ylabel('Amplitude'); title('Original Speech (8 kHz)'); grid on;
subplot(3,2,2); plot(t_synth,x_synth,'r','LineWidth',0.7); xlabel('Time (s)'); ylabel('Amplitude'); title(sprintf('Synthesized (BER=%.4f)',overall_BER)); grid on;
subplot(3,2,3); spectrogram(x_downsampled,hamming(256),128,512,Fs_target,'yaxis'); title('Original - Spectrogram'); ylim([0 4]); colorbar;
subplot(3,2,4); spectrogram(x_synth,hamming(256),128,512,Fs_target,'yaxis'); title('Synthesized - Spectrogram'); ylim([0 4]); colorbar;
subplot(3,2,5);
[Po,fp] = pwelch(x_downsampled,hamming(512),256,1024,Fs_target);
[Ps,~]  = pwelch(x_synth,hamming(512),256,1024,Fs_target);
plot(fp,10*log10(Po),'b','LineWidth',2); hold on;
plot(fp,10*log10(Ps),'r--','LineWidth',2);
legend('Original','Synthesized'); xlabel('Hz'); ylabel('PSD (dB/Hz)'); grid on; xlim([0 4000]);
subplot(3,2,6);
text(0.05,0.95,'QUALITY METRICS','FontSize',12,'FontWeight','bold');
if mean_lsd < 8
    lsd_color = [0 0.6 0]; lsd_note = '(< 8 dB = good)';
elseif mean_lsd < 12
    lsd_color = [0.8 0.5 0]; lsd_note = '(8-12 dB = acceptable)';
else
    lsd_color = [0.8 0 0]; lsd_note = '(> 12 dB = expected for 1 kbps vocoder)';
end
text(0.05,0.83,sprintf('Log Spectral Dist: %.2f dB  %s', mean_lsd, lsd_note),'FontWeight','bold','Color',lsd_color);
text(0.05,0.62,sprintf('BER: %.6f',overall_BER));
text(0.05,0.52,sprintf('Bit errors: %d / %d',bit_errors,length(rx_bits)));
text(0.05,0.40,'Waveform metrics:','FontSize',9,'Color',[0.5 0.5 0.5]);
text(0.05,0.31,sprintf('  SNR=%.2f dB, Corr=%.4f',snr_val,corr_val),'FontSize',9,'Color',[0.5 0.5 0.5]);
text(0.05,0.20,'* Low waveform SNR/Corr is EXPECTED','FontSize',8,'Color',[0.5 0.5 0.5]);
text(0.05,0.12,'  for parametric vocoders (phase not preserved)','FontSize',8,'Color',[0.5 0.5 0.5]);
text(0.05,0.03,'Method: Parametric Vocoder (LSF+Pitch+V/UV)','FontWeight','bold'); axis off;

% Figure: Per-packet BER
figure('Name','Per-Packet BER Analysis','Position',[50 50 1100 600]);
subplot(2,2,1); stem(1:num_frames,packet_BER,'filled','LineWidth',1.2); xlabel('Packet Index'); ylabel('BER'); title('Frame-Level BER'); grid on; ylim([0 max(0.1,max(packet_BER)+0.05)]);
subplot(2,2,2); plot(1:num_frames,packet_preamble_corr,'s-','LineWidth',1.5,'MarkerSize',6); xlabel('Packet Index'); ylabel('Correlation'); title('Preamble Correlation (max: 64)'); grid on; ylim([0 64]); yline(32,'r--','Threshold 50%','LineWidth',1.5);
subplot(2,2,3); bar([mean(packet_BER),median(packet_BER),min(packet_BER),max(packet_BER)]); set(gca,'XTickLabel',{'Mean','Median','Best','Worst'}); ylabel('BER'); title('BER Statistics'); grid on;
subplot(2,2,4);
gp=sum(packet_BER==0); mp=sum(packet_BER>0 & packet_BER<0.05); bp=sum(packet_BER>=0.05);
lbl={}; vals=[];
if gp>0; lbl{end+1}=sprintf('BER=0 (%d)',gp); vals(end+1)=gp; end
if mp>0; lbl{end+1}=sprintf('BER<5%% (%d)',mp); vals(end+1)=mp; end
if bp>0; lbl{end+1}=sprintf('BER>=5%% (%d)',bp); vals(end+1)=bp; end
if isempty(vals); vals=1; lbl={'No data'}; end
pie(vals,lbl); title(sprintf('Packet Quality (%d pkts)',num_frames));

fprintf('SYNTHESIS SUMMARY:\n');
fprintf('  Total bits:  %d\n', length(rx_bits));
fprintf('  Bit errors:  %d\n', bit_errors);
fprintf('  BER:         %.6f\n', overall_BER);
fprintf('  Accuracy:    %.4f%%\n', (1-overall_BER)*100);
fprintf('  Perfect pkts:%d / %d\n', sum(packet_BER==0), num_frames);
fprintf('  Duration:    %.3f s\n', length(x_synth)/Fs_target);
fprintf('  SNR:         %.2f dB\n', snr_val);
fprintf('  Correlation: %.4f\n\n', corr_val);

fprintf('════════════════════════════════════════════════════════════════════\n');
fprintf('  AUDIO COMPARISON — Press ENTER before each signal\n');
fprintf('════════════════════════════════════════════════════════════════════\n\n');

fprintf('  [1/3] ENTER -> Original corrupted signal (48 kHz, raw input)...\n'); pause;
soundsc(x, Fs_original); pause(duration + 0.5);

fprintf('  [2/3] ENTER -> Clean 8 kHz signal (filtered + downsampled)...\n'); pause;
soundsc(x_downsampled, Fs_target); pause(length(x_downsampled)/Fs_target + 0.5);

fprintf('  [3/3] ENTER -> Synthesized from RECEIVED BITS (USRP TX/RX)...\n'); pause;
soundsc(x_synth, Fs_target); pause(length(x_synth)/Fs_target + 0.5);

fprintf('\n  Audio comparison done!\n\n');

fprintf('\n════════════════════════════════════════════════════════════════════\n');
fprintf('              SPEECH SYNTHESIS PART 3 COMPLETED!\n');
fprintf('════════════════════════════════════════════════════════════════════\n\n');

%% ========================================================================
%% PART 4: BER vs Eb/N0 CHANNEL SIMULATION
%% ========================================================================

fprintf('\n════════════════════════════════════════════════════════════════════\n');
fprintf('  PART 4: CHANNEL NOISE SIMULATION - BER vs Eb/N0\n');
fprintf('════════════════════════════════════════════════════════════════════\n\n');

fprintf('STEP: BPSK SYSTEM PARAMETERS\n');
fprintf('────────────────────────────────────────────────────────────────────\n\n');
fprintf('  Symbol rate:   %d bps\n', symbol_rate);
fprintf('  Smp/Symbol:    %d\n', samples_per_symbol);
fprintf('  Baseband Fs:   %.1f kHz\n', Fs_baseband/1000);
fprintf('  RRC rolloff:   %.1f\n', rolloff);
fprintf('  Preamble:      %d bits\n', preamble_len);
fprintf('  Packet size:   %d bits\n\n', preamble_len + coded_bits_per_frame);

% Combined TX waveform for all frames
all_tx_bits_sim = [];
for fi = 1:num_frames
    all_tx_bits_sim = [all_tx_bits_sim; preamble_bits; tx_payload_frames(:,fi)];
end
tx_syms_sim = 2*double(all_tx_bits_sim) - 1;
tx_up_sim   = upsample(tx_syms_sim, samples_per_symbol);
tx_full_sim = conv(tx_up_sim, rrc_filter, 'full');
tx_shp_sim  = tx_full_sim(rrc_delay+1 : end-rrc_delay);
tx_shp_sim  = tx_shp_sim / max(abs(tx_shp_sim)) * 0.9;
Ps_sim      = mean(tx_shp_sim.^2);
Eb_sim      = Ps_sim * samples_per_symbol;

fprintf('REFERENCE WAVEFORM:\n');
fprintf('  Total bits:   %d\n', length(all_tx_bits_sim));
fprintf('  Signal power: %.4f\n', Ps_sim);
fprintf('  Eb:           %.4f\n\n', Eb_sim);

%% BER vs Eb/N0 Simulation
fprintf('STEP: BER vs Eb/N0 SIMULATION\n');
fprintf('────────────────────────────────────────────────────────────────────\n\n');

EbN0_dB_range = -2:1:14;
N_EbN0        = length(EbN0_dB_range);
BER_simulated = zeros(N_EbN0, 1);
BER_theory    = zeros(N_EbN0, 1);

fprintf('  Testing %d Eb/N0 points...\n\n', N_EbN0);

for idx = 1:N_EbN0
    EbN0_lin          = 10^(EbN0_dB_range(idx)/10);
    BER_theory(idx)   = 0.5 * erfc(sqrt(EbN0_lin));
    sigma2            = Eb_sim / (2*EbN0_lin);
    noise             = sqrt(sigma2) * randn(size(tx_shp_sim));
    rx_noisy          = tx_shp_sim + noise;
    rx_filt_full      = conv(rx_noisy, rrc_filter, 'full');
    rx_filtered       = rx_filt_full(rrc_delay+1 : end-rrc_delay);
    rx_sampled        = rx_filtered(1:samples_per_symbol:end);
    n_sym             = min(length(rx_sampled), length(tx_syms_sim));
    rx_bits_sim       = double(real(rx_sampled(1:n_sym)) > 0);
    tx_bits_sim       = double(tx_syms_sim(1:n_sym) > 0);
    BER_simulated(idx) = sum(rx_bits_sim ~= tx_bits_sim) / n_sym;
    fprintf('  Eb/N0 = %+4.1f dB | BER_sim = %.5f | BER_theory = %.5f\n', ...
        EbN0_dB_range(idx), BER_simulated(idx), BER_theory(idx));
end
fprintf('\n');

%% Speech Quality vs Eb/N0
fprintf('STEP: SPEECH QUALITY vs Eb/N0\n');
fprintf('────────────────────────────────────────────────────────────────────\n\n');

demo_EbN0_dB       = [2, 5, 8, 12];
N_demo             = length(demo_EbN0_dB);
speech_SNR_values  = zeros(N_demo, 1);
speech_corr_values = zeros(N_demo, 1);
speech_BER_values  = zeros(N_demo, 1);
synth_signals      = cell(N_demo, 1);
rx_sym_demo        = cell(N_demo, 1);
pkt_sym_len        = preamble_len + coded_bits_per_frame;

for d = 1:N_demo
    EbN0_lin   = 10^(demo_EbN0_dB(d)/10);
    sigma2     = Eb_sim / (2*EbN0_lin);
    noise      = sqrt(sigma2) * randn(size(tx_shp_sim));
    rx_noisy   = tx_shp_sim + noise;
    rx_ff_d    = conv(rx_noisy, rrc_filter, 'full');
    rx_filt_d  = rx_ff_d(rrc_delay+1 : end-rrc_delay);
    rx_samp_d  = rx_filt_d(1:samples_per_symbol:end);
    rx_sym_demo{d} = rx_samp_d;

    rx_bits_all = zeros(total_bits, 1);
    num_errors  = 0;

    for fi = 1:num_frames
        ps = (fi-1)*pkt_sym_len + 1;
        pe = ps + pkt_sym_len - 1;
        if pe > length(rx_samp_d); break; end
        pkt_s  = rx_samp_d(ps:pe);
        pre_s  = pkt_s(1:preamble_len);
        tx_pre2 = 2*double(preamble_bits) - 1;
        h_e    = sum(pre_s.*tx_pre2) / sum(tx_pre2.^2);
        pkt_eq = pkt_s / (h_e+eps);
        fr_rx_coded  = double(real(pkt_eq(preamble_len+1:end)) > 0);
        fr_rx_coded  = fr_rx_coded(1:coded_bits_per_frame);
        
        if use_interleaving
            fr_rx_deinterleaved = block_deinterleave(fr_rx_coded, ...
                interleaver_rows, interleaver_cols);
        else
            fr_rx_deinterleaved = fr_rx_coded;
        end

        if use_ecc
            fr_rx = hamming74_decode(fr_rx_deinterleaved);
        else
            fr_rx = fr_rx_deinterleaved;
        end
        
        num_errors = num_errors + sum(binary_frames(:,fi) ~= fr_rx);
        
        bs = (fi-1)*bits_per_frame+1;
        be = bs+bits_per_frame-1;
        
        if be <= total_bits
            rx_bits_all(bs:be) = fr_rx;
        end
    end
    speech_BER_values(d) = num_errors / total_bits;

    % Speech synthesis at this SNR
    rx_frm_d = reshape(rx_bits_all(1:bits_per_frame*num_frames), bits_per_frame, num_frames);
    x_synth_d    = zeros(total_samples, 1);
    ov_count_d   = zeros(total_samples, 1);

    for i = 1:num_frames
        s2 = (i-1)*frame_shift_samples+1; e2 = s2+frame_length_samples-1;
        if e2 > total_samples; break; end
        fr2 = rx_frm_d(:,i); ptr2 = 1;
        lsf_d2 = zeros(1,lpc_order);
        for j = 1:lpc_order
            b2 = fr2(ptr2:ptr2+lsf_bits-1)';
            lsf_d2(j) = (bi2de(b2,'left-msb')/(2^lsf_bits-1))*pi;
            ptr2 = ptr2+lsf_bits;
        end
        b2 = fr2(ptr2:ptr2+gain_bits-1)';
        gd2 = gain_db_min+(bi2de(b2,'left-msb')/(2^gain_bits-1))*gain_db_range;
        ptr2 = ptr2+gain_bits;
        b2 = fr2(ptr2:ptr2+pitch_bits-1)';
        pd2 = min_pitch+(bi2de(b2,'left-msb')/(2^pitch_bits-1))*(max_pitch-min_pitch);
        ptr2 = ptr2+pitch_bits;
        vd2 = fr2(ptr2);
        lsf_d2 = sort(max(1e-4,min(pi-1e-4,lsf_d2)));
        for k=2:lpc_order; if lsf_d2(k)-lsf_d2(k-1)<1e-3; lsf_d2(k)=lsf_d2(k-1)+1e-3; end; end
        lsf_d2 = min(pi-1e-4,lsf_d2);
        try; a2 = lsf2poly(lsf_d2); catch; a2 = [1 zeros(1,lpc_order)]; end
        if vd2 && pd2 > 0
            pp2 = max(1,round(Fs_target/pd2)); exc2 = zeros(frame_length_samples,1); exc2(1:pp2:end)=1;
        else; exc2 = randn(frame_length_samples,1); end
        sf2 = filter(1,a2,exc2);
        tr2 = 10^(gd2/20)*1e-3; sr2 = sqrt(mean(sf2.^2));
        if sr2>eps; sf2 = sf2*(tr2/sr2); end
        sf2w = sf2.*win;
        x_synth_d(s2:e2) = x_synth_d(s2:e2)+sf2w;
        ov_count_d(s2:e2) = ov_count_d(s2:e2)+win;
    end
    ov_count_d(ov_count_d<0.01)=1; x_synth_d=x_synth_d./ov_count_d;
    pk2=max(abs(x_synth_d)); if pk2>eps; x_synth_d=x_synth_d/pk2*0.95; end
    synth_signals{d} = x_synth_d;

    mn2 = min(length(x_downsampled),length(x_synth_d));
    o2 = x_downsampled(1:mn2); s2v = x_synth_d(1:mn2);
    sr2 = sqrt(mean(s2v.^2)); or2 = sqrt(mean(o2.^2));
    if sr2>eps; s2v = s2v*(or2/sr2); end
    cc2 = corrcoef(o2,s2v);
    speech_corr_values(d) = cc2(1,2);
    speech_SNR_values(d)  = 10*log10(sum(o2.^2)/(sum((o2-s2v).^2)+eps));

    fprintf('  Eb/N0=%2d dB | BER=%.5f | SNR_speech=%.2f dB | Corr=%.4f\n', ...
        demo_EbN0_dB(d), speech_BER_values(d), speech_SNR_values(d), speech_corr_values(d));

    
end
fprintf('\n');

%% Visualization: BER vs Eb/N0
figure('Name','BER vs Eb/N0 - BPSK AWGN', ...
       'Position',[50 50 900 600], 'Color','w');

% 1) Theoretical BPSK AWGN BER
semilogy(EbN0_dB_range, BER_theory, 'b-', 'LineWidth',2.5, ...
    'DisplayName','Theoretical (BPSK AWGN)');
hold on;

% 2) Simulated raw BER before ECC
semilogy(EbN0_dB_range, BER_simulated, 'r--o', 'LineWidth',2, ...
    'MarkerSize',7, 'MarkerFaceColor','r', ...
    'DisplayName','Simulation');

% 3) Mark demo Eb/N0 points
for d = 1:N_demo
    [~,di] = min(abs(EbN0_dB_range - demo_EbN0_dB(d)));

    h_demo = semilogy(demo_EbN0_dB(d), BER_simulated(di), 'ks', ...
        'MarkerSize',12, 'LineWidth',2);
    h_demo.HandleVisibility = 'off';

    text(demo_EbN0_dB(d)+0.3, BER_simulated(di), ...
        sprintf('%d dB', demo_EbN0_dB(d)), ...
        'FontSize',10, 'FontWeight','bold');
end

% 4) Add real USRP measurement
real_SNR_dB  = mean(snr_evm_packet, 'omitnan');     % EVM-based estimated SNR
real_raw_BER = mean(packet_BER_raw, 'omitnan');     % Raw BER before ECC

% For semilogy, BER cannot be exactly zero
total_raw_bits = num_frames * coded_bits_per_frame;
real_raw_BER_plot = max(real_raw_BER, 1/total_raw_bits);

semilogy(real_SNR_dB, real_raw_BER_plot, 'kp', ...
    'MarkerSize',14, ...
    'LineWidth',2.2, ...
    'MarkerFaceColor','y', ...
    'DisplayName','Real USRP Raw BER');

text(real_SNR_dB + 0.25, real_raw_BER_plot*1.3, ...
    {sprintf('Real USRP'), ...
     sprintf('SNR=%.2f dB', real_SNR_dB), ...
     sprintf('Raw BER=%.4g', real_raw_BER)}, ...
    'FontSize',10, ...
    'FontWeight','bold', ...
    'Color','k');

% 5) BER reference line
h_line = yline(1e-3, 'g--', 'LineWidth',1.5, 'Label','BER = 10^{-3}');
h_line.HandleVisibility = 'off';

xlabel('E_b/N_0 (dB)','FontSize',13);
ylabel('Bit Error Rate (BER)','FontSize',13);
title('Raw BPSK BER vs E_b/N_0 Before ECC','FontSize',14,'FontWeight','bold');

legend('Location','southwest','FontSize',11);

grid on; grid minor;
xlim([min(EbN0_dB_range) max(EbN0_dB_range)]);
ylim([1e-5 1]);
%% Visualization: Constellation at different Eb/N0
figure('Name','BPSK Constellation at Different Eb/N0','Position',[50 100 1400 400],'Color','w');
for d = 1:N_demo
    subplot(1,N_demo,d);
    EbN0_lc = 10^(demo_EbN0_dB(d)/10);
    sig2c   = Eb_sim/(2*EbN0_lc);
    nc      = sqrt(sig2c)*(randn(size(tx_shp_sim))+1j*randn(size(tx_shp_sim)));
    rxc     = tx_shp_sim + nc;
    rxfc    = conv(rxc,rrc_filter,'full'); rxfc=rxfc(rrc_delay+1:end-rrc_delay);
    rxsc    = rxfc(1:samples_per_symbol:end);
    nsh     = min(500,length(rxsc));
    scatter(real(rxsc(1:nsh)),imag(rxsc(1:nsh)),15,'filled','MarkerFaceAlpha',0.5,'MarkerFaceColor',[0.2 0.4 0.8]);
    hold on; plot([-1 1],[0 0],'r*','MarkerSize',14,'LineWidth',2); xline(0,'--k','LineWidth',1.2);
    xlabel('In-Phase'); ylabel('Quadrature');
    title(sprintf('E_b/N_0 = %d dB\nPost-ECC BER = %.4f',demo_EbN0_dB(d), speech_BER_values(d)), 'FontSize',11,'FontWeight','bold');
    grid on; axis equal; xlim([-2 2]); ylim([-2 2]);
end
sgtitle('BPSK Constellation - Different Channel Conditions','FontSize',13,'FontWeight','bold');

%% Visualization: Synthesized speech at different Eb/N0
figure('Name','Synthesized Speech at Different Eb/N0','Position',[50 150 1400 700],'Color','w');
n_cols_fig = N_demo + 1;   % +1 for original
subplot(2,n_cols_fig,1);
t_o = (0:length(x_downsampled)-1)/Fs_target;
plot(t_o,x_downsampled,'b','LineWidth',0.7); xlabel('Time (s)'); title('Original','FontSize',11,'FontWeight','bold'); grid on;
for d=1:N_demo
    subplot(2,n_cols_fig,d+1);
    t_s=(0:length(synth_signals{d})-1)/Fs_target;
    plot(t_s,synth_signals{d},'Color',[0.8 0.2 0.2],'LineWidth',0.7);
    xlabel('Time (s)'); title(sprintf('E_b/N_0=%d dB\nBER=%.4f',demo_EbN0_dB(d),speech_BER_values(d)),'FontSize',11,'FontWeight','bold'); grid on;
end
subplot(2,n_cols_fig,n_cols_fig+1);
spectrogram(x_downsampled,hamming(256),128,512,Fs_target,'yaxis'); title('Original'); ylim([0 4]); colorbar;
for d=1:N_demo
    subplot(2,n_cols_fig,n_cols_fig+1+d);
    spectrogram(synth_signals{d},hamming(256),128,512,Fs_target,'yaxis');
    title(sprintf('E_b/N_0=%d dB',demo_EbN0_dB(d)),'FontSize',11,'FontWeight','bold'); ylim([0 4]); colorbar;
end
sgtitle('Synthesized Speech - Different Channel Conditions','FontSize',13,'FontWeight','bold');

%% Visualization: Speech quality vs Eb/N0
figure('Name','Speech Quality vs Eb/N0','Position',[50 200 1000 500],'Color','w');
subplot(1,2,1);
yyaxis left;  plot(demo_EbN0_dB,speech_SNR_values,'bo-','LineWidth',2,'MarkerSize',8,'MarkerFaceColor','b'); ylabel('Speech SNR (dB)','FontSize',12);
yyaxis right; plot(demo_EbN0_dB,speech_corr_values,'rs-','LineWidth',2,'MarkerSize',8,'MarkerFaceColor','r'); ylabel('Correlation','FontSize',12);
xlabel('E_b/N_0 (dB)','FontSize',12); title('Speech Quality vs E_b/N_0','FontSize',13,'FontWeight','bold');
legend('SNR_{speech}','Correlation','Location','best','FontSize',11); grid on;
subplot(1,2,2);

speech_BER_plot = speech_BER_values;
speech_BER_plot(speech_BER_plot == 0) = 1e-5;

semilogy(demo_EbN0_dB, speech_BER_plot, 'ko-', ...
    'LineWidth',2,'MarkerSize',8,'MarkerFaceColor','k');

xlabel('E_b/N_0 (dB)','FontSize',12);
ylabel('BER','FontSize',12);
title('Post-ECC BER vs E_b/N_0 (Demo Points)','FontSize',13,'FontWeight','bold');
grid on;
ylim([1e-5 1]);

for d = 1:N_demo
    if speech_BER_values(d) == 0
        txt = 'BER=0';
    else
        txt = sprintf('%.4f', speech_BER_values(d));
    end

    text(demo_EbN0_dB(d), speech_BER_plot(d)*1.8, txt, ...
        'HorizontalAlignment','center', ...
        'FontSize',9, ...
        'FontWeight','bold');
end

text(mean(demo_EbN0_dB), 2e-5, ...
    'BER=0 plotted as 10^{-5} for log scale', ...
    'HorizontalAlignment','center', ...
    'FontSize',8);

%% Visualization: Summary bar charts
figure('Name','System Performance Summary','Position',[50 250 1000 400],'Color','w');
subplot(1,2,1);
bar_data = [BER_theory, BER_simulated];
b_bar2 = bar(EbN0_dB_range,bar_data,'grouped');
b_bar2(1).FaceColor=[0.2 0.4 0.8]; b_bar2(2).FaceColor=[0.8 0.2 0.2];
set(gca,'YScale','log'); xlabel('E_b/N_0 (dB)'); ylabel('BER');
title('Theoretical vs Simulation BER','FontWeight','bold');
legend('Theoretical','Simulation','Location','best'); grid on; ylim([1e-5 1]);
subplot(1,2,2);

% BER=0 values cannot be shown on a logarithmic axis.
% Therefore, only for plotting, replace zero BER with 1e-5.
ber_plot = speech_BER_values;
ber_plot(ber_plot == 0) = 1e-5;

cats = categorical({'2 dB','5 dB','8 dB','12 dB'});
cats = reordercats(cats, {'2 dB','5 dB','8 dB','12 dB'});

b_bar3 = bar(cats, ber_plot, 'FaceColor','flat');

cdata = [0.8 0.2 0.2;
         0.8 0.5 0.1;
         0.2 0.7 0.3;
         0.2 0.4 0.8];

for d = 1:N_demo
    b_bar3.CData(d,:) = cdata(d,:);
end

set(gca,'YScale','log');
ylabel('BER');
title('Demo Points BER','FontWeight','bold');
grid on;
ylim([1e-5 1]);

% Add real BER values as labels above bars
for d = 1:N_demo
    if speech_BER_values(d) == 0
        label_txt = 'BER=0';
    else
        label_txt = sprintf('%.4f', speech_BER_values(d));
    end

    text(d, ber_plot(d)*1.5, label_txt, ...
        'HorizontalAlignment','center', ...
        'FontSize',9, ...
        'FontWeight','bold');
end

text(2.5, 2e-5, 'BER=0 is plotted as 10^{-5} for log scale', ...
    'HorizontalAlignment','center', ...
    'FontSize',8);
sgtitle('EE3001 - System Performance Summary','FontSize',13,'FontWeight','bold');

% Summary table
fprintf('SUMMARY TABLE:\n');
fprintf('  %-10s | %-12s | %-12s | %-12s | %-12s\n', ...
    'Eb/N0','Theory','Raw Sim','Post-ECC','SNRspeech');

for d=1:N_demo
    [~,idx]=min(abs(EbN0_dB_range-demo_EbN0_dB(d)));
    fprintf('  %-10d | %-12.5f | %-12.5f | %-12.5f | %-12.2f\n', ...
        demo_EbN0_dB(d), BER_theory(idx), BER_simulated(idx), ...
        speech_BER_values(d), speech_SNR_values(d));
end
fprintf('\n');

% Part 4 audio playback is optional — it can be skipped in the demo
% Audio for each channel condition was saved to speech_EbN0_*dB.wav files

%% ========================================================================
%% FINAL SUMMARY
%% ========================================================================

fprintf('\n');
fprintf('════════════════════════════════════════════════════════════════════\n');
fprintf('════════════════════════════════════════════════════════════════════\n');
fprintf('                       PROJECT SUMMARY\n');
fprintf('════════════════════════════════════════════════════════════════════\n\n');

fprintf('  PART 1 - DSP\n');
fprintf('    Filter      : FIR Kaiser, order %d, cutoff %.1f kHz\n', filter_order, Fc/1000);
fprintf('    Downsample  : 48 kHz -> 8 kHz (1:%d)\n', decimation_factor);
fprintf('    LPC         : order %d, %d frames\n', lpc_order, num_frames);
fprintf('    Binary      : %d bit (%d bit/frame)\n', total_bits, bits_per_frame);
fprintf('    Compression : 1:%.0f\n\n', bytes_original/total_bytes);

fprintf('  PART 2 - BPSK\n');
fprintf('    Carrier     : %.1f MHz\n', carrier_freq_usrp/1e6);
fprintf('    Symbol rate : %d bps\n', symbol_rate);
fprintf('    Raw BER     : %.6f\n', mean(packet_BER_raw));
fprintf('    Post-ECC BER: %.6f\n', overall_BER);
if use_interleaving
    fprintf('    Interleaver : %d x %d block interleaver\n', ...
        interleaver_rows, interleaver_cols);
end
if use_interleaving
    fprintf('  Interleaving:  ON (%d x %d block)\n', interleaver_rows, interleaver_cols);
else
    fprintf('  Interleaving:  OFF\n');
end
fprintf('    Bit errors  : %d / %d\n', bit_errors, length(binary_data));
fprintf('    Perfect pkts: %d / %d\n\n', sum(packet_BER==0), num_frames);

fprintf('  PART 3 - SYNTHESIS\n');
fprintf('    Log Spectral Dist  : %.2f dB  (lower is better)\n', mean_lsd);
fprintf('    BER effect         : %d bit errors / %d bits\n', bit_errors, length(binary_data));
fprintf('    Waveform SNR       : %.2f dB  (normal for a parametric vocoder)\n\n', snr_val);


fprintf('\n');
fprintf('════════════════════════════════════════════════════════════════════\n');
fprintf('                 PIPELINE COMPLETED!\n');
fprintf('════════════════════════════════════════════════════════════════════\n\n');

%% ========================================================================
%% LOCAL FUNCTIONS: HAMMING(7,4) ECC
%% ========================================================================

function coded = hamming74_encode(bits)
    bits = bits(:);

    if mod(length(bits),4) ~= 0
        error('Hamming(7,4) requires input length to be divisible by 4.');
    end

    num_blocks = length(bits)/4;
    coded = zeros(num_blocks*7,1);

    for k = 1:num_blocks
        idx = (k-1)*4 + 1;
        d = bits(idx:idx+3);

        d1 = d(1);
        d2 = d(2);
        d3 = d(3);
        d4 = d(4);

        % Hamming(7,4) bit layout:
        % [p1 p2 d1 p3 d2 d3 d4]
        p1 = mod(d1 + d2 + d4, 2);
        p2 = mod(d1 + d3 + d4, 2);
        p3 = mod(d2 + d3 + d4, 2);

        c = [p1; p2; d1; p3; d2; d3; d4];

        coded((k-1)*7 + 1 : k*7) = c;
    end
end

function decoded = hamming74_decode(coded)
    coded = coded(:);

    if mod(length(coded),7) ~= 0
        error('Hamming(7,4) requires coded length to be divisible by 7.');
    end

    num_blocks = length(coded)/7;
    decoded = zeros(num_blocks*4,1);

    for k = 1:num_blocks
        idx = (k-1)*7 + 1;
        r = coded(idx:idx+6);

        % Syndrome checks for bit layout:
        % [p1 p2 d1 p3 d2 d3 d4]
        s1 = mod(r(1) + r(3) + r(5) + r(7), 2);
        s2 = mod(r(2) + r(3) + r(6) + r(7), 2);
        s3 = mod(r(4) + r(5) + r(6) + r(7), 2);

        error_pos = s1*1 + s2*2 + s3*4;

        % Correct one-bit error if syndrome is nonzero
        if error_pos >= 1 && error_pos <= 7
            r(error_pos) = 1 - r(error_pos);
        end

        % Extract data bits: [d1 d2 d3 d4]
        d = [r(3); r(5); r(6); r(7)];

        decoded((k-1)*4 + 1 : k*4) = d;
    end
end
function y = block_interleave(x, n_rows, n_cols)
    x = x(:);

    if length(x) ~= n_rows*n_cols
        error('Interleaver input length must equal n_rows*n_cols.');
    end

    % Write row-wise, read column-wise
    mat = reshape(x, n_cols, n_rows).';
    y = mat(:);
end

function x = block_deinterleave(y, n_rows, n_cols)
    y = y(:);

    if length(y) ~= n_rows*n_cols
        error('Deinterleaver input length must equal n_rows*n_cols.');
    end

    % Inverse of block_interleave
    mat = reshape(y, n_rows, n_cols);
    x = reshape(mat.', [], 1);
end