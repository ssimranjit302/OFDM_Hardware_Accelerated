function [ber, ser, txSig, rxSig, rxConst, throughput] = core_ofdm_software(snrDB, numSymbols, isFixedPoint, wordLen, fracLen)
    % core_ofdm_software: Baseline Software OFDM Transceiver Chain
    
    if nargin < 3
        isFixedPoint = false;
    end
    if isFixedPoint && (nargin < 5)
        error('wordLen and fracLen required for fixed point');
    end

    % Parameters
    N = 64;             % OFDM subcarriers
    M = 16;             % 16-QAM
    k = log2(M);        % bits/symbol
    cpLen = 16;         % Cyclic Prefix length
    
    % Pulse Shaping
    rolloff = 0.25;
    span = 10;
    sps = 4;
    rrc = rcosdesign(rolloff, span, sps, 'sqrt');
    totalDelay = span * sps;
    mfGain = sum(rrc.^2);
    
    rng(1); % Seed for reproducible comparison across sweeps

    % TX
    txBits = randi([0 1], numSymbols * k, 1);
    txQAM = qammod(txBits, M, 'InputType', 'bit', 'UnitAveragePower', true);
    txSymIdx = qamdemod(txQAM, M, 'OutputType', 'integer', 'UnitAveragePower', true);

    numOFDM = ceil(numSymbols / N);
    txQAM_padded = [txQAM; zeros(numOFDM * N - numSymbols, 1)];
    dataMatrix = reshape(txQAM_padded, N, numOFDM);

    txIFFT = ifft(dataMatrix, N, 1);
    txOFDM_cp = [txIFFT(end - cpLen + 1 : end, :); txIFFT];
    txSignal = txOFDM_cp(:);
    L = length(txSignal);
    
    if isFixedPoint
        T = numerictype(1, wordLen, fracLen);
        F = fimath('RoundingMethod', 'Nearest', 'OverflowAction', 'Saturate');
        txSignal = double(fi(txSignal, T, F)); 
    end
    
    txUps = upsample(txSignal, sps);
    txShaped = conv(txUps, rrc, 'full');
    
    % Channel
    noisy = awgn(txShaped, snrDB, 'measured');
    
    % RX
    rxMF = conv(noisy, rrc, 'full');
    rxRec = rxMF(totalDelay+1 : sps : totalDelay+L*sps);
    rxSignal = rxRec / mfGain;
    
    rxMat = reshape(rxSignal, N+cpLen, []);
    rxFFT = fft(rxMat(cpLen+1:end, :), N, 1);
    
    % For output plotting
    txSig = txSignal;
    rxSig = rxSignal;
    rxConst = rxFFT(:);
    rxConst = rxConst(1:numSymbols); % Truncate padding
    
    rxBits = qamdemod(rxConst, M, 'OutputType', 'bit', 'UnitAveragePower', true);
    rxSymIdx = qamdemod(rxConst, M, 'OutputType', 'integer', 'UnitAveragePower', true);
    
    [~, ber] = biterr(txBits, rxBits);
    ser = mean(rxSymIdx ~= txSymIdx);
    
    % Throughput Calculation (for capacity plot)
    frameBits = 1024;
    numFrames = floor(length(txBits) / frameBits);
    if numFrames > 0
        txFrames = reshape(txBits(1:numFrames*frameBits), frameBits, []);
        rxFrames = reshape(rxBits(1:numFrames*frameBits), frameBits, []);
        frameErrors = sum(any(txFrames ~= rxFrames, 1));
        PER = frameErrors / numFrames;
        
        symbolRate = 1e6; % 1 Msps
        maxBitrate = k * symbolRate;
        throughput = maxBitrate * (1 - PER);
    else
        throughput = 0;
    end
end
