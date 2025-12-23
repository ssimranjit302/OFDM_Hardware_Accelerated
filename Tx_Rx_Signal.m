%% -------- Parameters --------
M   = 16;
k   = log2(M);
Nsym = 200;        % symbols to visualize
sps = 4;           % samples per symbol
rolloff = 0.25;
span = 10;

%% -------- Generate QAM symbols --------
bits = randi([0 1], Nsym*k, 1);
txSym = qammod(bits, M, ...
    'InputType','bit', ...
    'UnitAveragePower', true);

%% -------- sqrt-RRC filter --------
rrc = rcosdesign(rolloff, span, sps, 'sqrt');

%% -------- Pulse shaping --------
txUps = upsample(txSym, sps);
txShaped = conv(txUps, rrc, 'full');

%% -------- Time axis (for TX plot) --------
t = (0:length(txShaped)-1)/sps;

%% ===================== PLOT 1 =====================
figure;

subplot(2,1,1)
plot(t, real(txShaped), 'b', 'LineWidth', 1); hold on;
plot(t, imag(txShaped), 'r', 'LineWidth', 1);
grid on;
xlabel('Time (symbols)');
ylabel('Amplitude');
title('Pulse-Shaped Transmit Signal (sqrt-RRC)');
legend('In-phase','Quadrature');

%% -------- AWGN channel (moderate SNR) --------
SNRdB = 10;
rxSignal = awgn(txShaped, SNRdB, 'measured');

%% -------- Matched filtering --------
rxMF = conv(rxSignal, rrc, 'full');

% Total group delay (TX + RX)
totalDelay = span*sps;

% Downsample at symbol rate
rxSamples = rxMF(totalDelay+1 : sps : totalDelay + Nsym*sps);

%% ===================== PLOT 2 =====================
subplot(2,1,2)
stem(real(rxSamples), 'bo', 'LineWidth', 1); hold on;
stem(imag(rxSamples), 'ro', 'LineWidth', 1);
grid on;
xlabel('Symbol Index');
ylabel('Amplitude');
title('Retrieved Rx Signal (After Matched Filter & Downsample)');
legend('In-phase','Quadrature');
