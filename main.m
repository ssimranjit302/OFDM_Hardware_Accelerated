clc; close all; clear;

%% ===================== Parameters =====================
N = 64;                 % OFDM subcarriers
M = 16;                 % 16-QAM
k = log2(M);            % bits per symbol
numSymbols = 1e5;       % number of QAM symbols
cpLen = 16;             % cyclic prefix

SNRdB_vec = 0:1:25;
numSNR = length(SNRdB_vec);

%% ===================== Transmitter =====================
rng(1);

% Bit generation
txBits = randi([0 1], numSymbols*k, 1);

% QAM modulation
txQAM = qammod(txBits, M, ...
    'InputType','bit', ...
    'UnitAveragePower', true);

% Reference symbol indices (for SER)
txSymIdx = qamdemod(txQAM, M, ...
    'OutputType','integer', ...
    'UnitAveragePower', true);

%% ===================== OFDM Modulation =====================
numOFDM = ceil(numSymbols/N);
txQAM_padded = [txQAM; zeros(numOFDM*N-numSymbols,1)];
dataMatrix = reshape(txQAM_padded, N, numOFDM);

txIFFT = ifft(dataMatrix, N, 1);

% Add cyclic prefix
txOFDM_cp = [txIFFT(end-cpLen+1:end,:); txIFFT];
txSignal = txOFDM_cp(:);
L = length(txSignal);

%% ===================== Pulse Shaping =====================
rolloff = 0.25;
span = 10;
sps = 4;

rrc = rcosdesign(rolloff, span, sps, 'sqrt');
totalDelay = span*sps;
mfGain = sum(rrc.^2);

txUps = upsample(txSignal, sps);
txShaped = conv(txUps, rrc, 'full');

%% ===================== Fixed-Point =====================
wordLen = 16;
fracLen = 12;

T = numerictype(1,wordLen,fracLen);
F = fimath('RoundingMethod','Nearest','OverflowAction','Saturate');

tx_fixed = fi(txSignal,T,F);
txUps_fx = upsample(double(tx_fixed),sps);
txShaped_fx = conv(txUps_fx, double(rrc), 'full');

fprintf('Fixed-point format: %d-bit signed, %d fractional bits\n', ...
    wordLen, fracLen);

%% ===================== Result Storage =====================
BER_float = zeros(numSNR,1);
SER_float = zeros(numSNR,1);
BER_fixed = zeros(numSNR,1);
SER_fixed = zeros(numSNR,1);

%% ===================== Simulation Loop =====================
for iSNR = 1:numSNR
    SNRdB = SNRdB_vec(iSNR);

    %% ----- Floating-point path -----
    noisy_f = awgn(txShaped, SNRdB, 'measured');
    rxMF_f = conv(noisy_f, rrc, 'full');
    rxRec_f = rxMF_f(totalDelay+1:sps:totalDelay+L*sps);
    rxSignal_f = rxRec_f / mfGain;

    rxMat_f = reshape(rxSignal_f, N+cpLen, []);
    rxFFT_f = fft(rxMat_f(cpLen+1:end,:), N, 1);

    rxBits_f = qamdemod(rxFFT_f(:), M, ...
        'OutputType','bit','UnitAveragePower',true);
    rxBits_f = rxBits_f(1:length(txBits));

    rxSymIdx_f = qamdemod(rxFFT_f(:), M, ...
        'OutputType','integer','UnitAveragePower',true);
    rxSymIdx_f = rxSymIdx_f(1:numSymbols);

    [~, BER_float(iSNR)] = biterr(txBits, rxBits_f);
    SER_float(iSNR) = mean(rxSymIdx_f ~= txSymIdx);

    %% ----- Fixed-point path -----
    noisy_fx = awgn(txShaped_fx, SNRdB, 'measured');
    rxMF_fx = conv(noisy_fx, double(rrc), 'full');
    rxRec_fx = rxMF_fx(totalDelay+1:sps:totalDelay+L*sps);
    rxSignal_fx = rxRec_fx / mfGain;

    rxMat_fx = reshape(rxSignal_fx, N+cpLen, []);
    rxFFT_fx = fft(rxMat_fx(cpLen+1:end,:), N, 1);

    rxBits_fx = qamdemod(rxFFT_fx(:), M, ...
        'OutputType','bit','UnitAveragePower',true);
    rxBits_fx = rxBits_fx(1:length(txBits));

    rxSymIdx_fx = qamdemod(rxFFT_fx(:), M, ...
        'OutputType','integer','UnitAveragePower',true);
    rxSymIdx_fx = rxSymIdx_fx(1:numSymbols);

    [~, BER_fixed(iSNR)] = biterr(txBits, rxBits_fx);
    SER_fixed(iSNR) = mean(rxSymIdx_fx ~= txSymIdx);

    fprintf('SNR=%2d dB | Float: BER=%g SER=%g | Fixed: BER=%g SER=%g\n', ...
        SNRdB, BER_float(iSNR), SER_float(iSNR), ...
        BER_fixed(iSNR), SER_fixed(iSNR));
end

%% ===================== PLOTS =====================

figure;
semilogy(SNRdB_vec, BER_float,'-o','LineWidth',1.5); hold on;
semilogy(SNRdB_vec, BER_fixed,'-s','LineWidth',1.5);
grid on;
xlabel('SNR (dB)');
ylabel('Bit Error Rate (BER)');
legend('Floating-point','Fixed-point');
title('BER vs SNR for 16-QAM OFDM');

figure;
semilogy(SNRdB_vec, SER_float,'-o','LineWidth',1.5); hold on;
semilogy(SNRdB_vec, SER_fixed,'-s','LineWidth',1.5);
grid on;
xlabel('SNR (dB)');
ylabel('Symbol Error Rate (SER)');
legend('Floating-point','Fixed-point');
title('SER vs SNR for 16-QAM OFDM');

% PSD comparison
figure;
subplot(2,1,1);
pwelch(double(tx_fixed),[],[],[],1,'centered');
title('PSD of OFDM Signal (Fixed), No RRC'); grid on;

subplot(2,1,2);
pwelch(txShaped,[],[],[],1,'centered');
title('PSD of Pulse Shaped Signal (RRC)'); grid on;

%% -------- Constellation plots at different SNRs --------
snrList = [5 15 20];      % SNR values to visualize
numPts  = 3000;          % points to plot (keep small for clarity)

figure;
for ksnr = 1:length(snrList)
    SNRdB = snrList(ksnr);

    % Add AWGN directly on QAM symbols
    rxQAM = awgn(txQAM, SNRdB, 'measured');

    % Plot
    subplot(1,3,ksnr);
    scatter(real(rxQAM(1:numPts)), imag(rxQAM(1:numPts)), ...
        8, 'y', 'filled');

    grid on;
    axis square;
    xlim([-1.5 1.5]); ylim([-1.5 1.5]);
    set(gca,'Color','k');

    xlabel('I'); ylabel('Q');
    title(['Rx Constellation, SNR = ', num2str(SNRdB), ' dB']);
end
