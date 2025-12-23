%% -------- OFDM symbol with Cyclic Prefix --------
N = 64;          % subcarriers
cpLen = 16;      % cyclic prefix length
M = 16;

% One OFDM symbol
bits = randi([0 1], N*log2(M), 1);
qamSym = qammod(bits, M, 'InputType','bit','UnitAveragePower',true);

ofdmSym = ifft(qamSym, N);
ofdmCP  = [ofdmSym(end-cpLen+1:end); ofdmSym];

n = 0:length(ofdmCP)-1;

figure;
plot(n, real(ofdmCP), 'b','LineWidth',1.2); hold on;
plot(n, imag(ofdmCP), 'r--','LineWidth',1.2);
xline(cpLen,'k--','LineWidth',1.5);

grid on;
xlabel('Sample Index');
ylabel('Amplitude');
title('OFDM Symbol with Cyclic Prefix');
legend('In-phase (I)','Quadrature (Q)','CP boundary');
