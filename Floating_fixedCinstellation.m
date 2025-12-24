%% -------- Constellation comparison (Float vs Fixed) --------
M = 16;
k = log2(M);
numSym = 3000;
SNRdB = 20;

% Transmitted symbols
bits = randi([0 1], numSym*k, 1);
txSym = qammod(bits, M, 'InputType','bit','UnitAveragePower',true);

% Floating-point
rxFloat = awgn(txSym, SNRdB, 'measured');

% Fixed-point Q(4.12)
wordLen = 16; fracLen = 12;
T = numerictype(1, wordLen, fracLen);
F = fimath('RoundingMethod','Nearest','OverflowAction','Saturate');

txFixed = fi(txSym, T, F);
rxFixed = awgn(double(txFixed), SNRdB, 'measured');

% Ideal constellation
refConst = qammod(0:M-1, M, 'UnitAveragePower',true);

figure;

% ---- Floating-point ----
subplot(1,2,1)
scatter(real(rxFloat), imag(rxFloat), 10,'b','filled'); hold on;
scatter(real(refConst), imag(refConst), 80,'y','filled');
grid on; axis square;
xlim([-1.5 1.5]); ylim([-1.5 1.5]);
xlabel('In-phase'); ylabel('Quadrature');
title('Floating-Point (SNR = 20 dB)');
legend('Received Symbols','Ideal Points');

% ---- Fixed-point ----
subplot(1,2,2)
scatter(real(rxFixed), imag(rxFixed), 10,'r','filled'); hold on;
scatter(real(refConst), imag(refConst), 80,'y','filled');
grid on; axis square;
xlim([-1.5 1.5]); ylim([-1.5 1.5]);
xlabel('In-phase'); ylabel('Quadrature');
title('Fixed-Point Q(4.12) (SNR = 20 dB)');
legend('Received Symbols','Ideal Points');
