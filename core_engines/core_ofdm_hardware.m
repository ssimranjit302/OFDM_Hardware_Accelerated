function [ber, ser, txSig, rxSig, rxConst, throughput] = core_ofdm_hardware(snrDB, numSymbols, wordLen, fracLen)
    % core_ofdm_hardware: 8-Core Spatial Parallelism HW-Accurate OFDM Chain
    
    if nargin < 3
        wordLen = 16;
        fracLen = 12;
    end

    % Parameters
    N = 64;             % OFDM subcarriers
    M = 16;             % 16-QAM
    k = log2(M);        % bits/symbol
    numCores = 8;       % Spatial Parallelism Cores
    cpLen = 16;         % Cyclic Prefix length
    
    % Pulse Shaping
    rolloff = 0.25;
    span = 10;
    sps = 4;
    rrc = rcosdesign(rolloff, span, sps, 'sqrt');
    totalDelay = span * sps;
    mfGain = sum(rrc.^2);
    
    rng(1); % Seed for reproducible comparison across sweeps

    % TX Bits & QAM
    txBits = randi([0 1], numSymbols * k, 1);
    txQAM = qammod(txBits, M, 'InputType', 'bit', 'UnitAveragePower', true);
    txSymIdx = qamdemod(txQAM, M, 'OutputType', 'integer', 'UnitAveragePower', true);

    numOFDM = ceil(numSymbols / N);
    txQAM_padded = [txQAM; zeros(numOFDM * N - numSymbols, 1)];
    dataMatrix = reshape(txQAM_padded, N, numOFDM);

    % Define Fixed Point Format
    T = numerictype(1, wordLen, fracLen);
    F = fimath('RoundingMethod', 'Nearest', 'OverflowAction', 'Saturate'); 
    
    % Initialize 8 IFFT and 8 FFT Hardware Cores
    ifftHW = cell(1, numCores);
    fftHW = cell(1, numCores);
    for c = 1:numCores
        ifftHW{c} = dsphdl.IFFT('FFTLengthSource', 'Property', 'FFTLength', N, 'Normalize', true, 'BitReversedOutput', false, 'Architecture', 'Streaming Radix 2^2', 'RoundingMethod', 'Round', 'OverflowAction', 'Saturate');
        fftHW{c}  = dsphdl.FFT('FFTLengthSource', 'Property', 'FFTLength', N, 'Normalize', false, 'BitReversedOutput', false, 'Architecture', 'Streaming Radix 2^2', 'RoundingMethod', 'Round', 'OverflowAction', 'Saturate');
    end
    
    % Hardware Tx (Parallel IFFT)
    dataMatrix_fx = fi(dataMatrix, T, F);
    txIFFT_hw = complex(zeros(N, numOFDM));
    
    % Distribute symbols to the 8 cores
    for symIdx = 1:numOFDM
        coreIdx = mod(symIdx - 1, numCores) + 1;
        dataIn = dataMatrix_fx(:, symIdx);
        
        hw_out = complex(zeros(N, 1));
        outIdx = 1;
        for i = 1:N
            [dOut, vOut] = ifftHW{coreIdx}(dataIn(i), true);
            if vOut, hw_out(outIdx) = dOut; outIdx = outIdx + 1; end
        end
        % Drain pipeline
        zero_val = dataIn(1); zero_val(:) = 0;
        while outIdx <= N
            [dOut, vOut] = ifftHW{coreIdx}(zero_val, false);
            if vOut, hw_out(outIdx) = dOut; outIdx = outIdx + 1; end
        end
        txIFFT_hw(:, symIdx) = hw_out;
    end
    
    % Pulse Shaping (HW Output)
    txOFDM_cp_hw = [txIFFT_hw(end - cpLen + 1 : end, :); txIFFT_hw];
    txSignal_hw = txOFDM_cp_hw(:);
    txSignal_hw_fi = fi(txSignal_hw, T, F); 
    txUps_hw = upsample(double(txSignal_hw_fi), sps);
    txShaped_hw = conv(txUps_hw, double(rrc), 'full');
    
    % Channel
    noisy_hw = awgn(txShaped_hw, snrDB, 'measured');
    
    % Receiver (MF)
    rxMF_hw = conv(noisy_hw, double(rrc), 'full');
    rxRec_hw = rxMF_hw(totalDelay+1 : sps : totalDelay+length(txSignal_hw)*sps);
    rxSignal_hw = rxRec_hw / mfGain;

    rxMat_hw = reshape(rxSignal_hw, N+cpLen, []);
    rxMat_hw_noCP = rxMat_hw(cpLen+1:end, :);
    rxMat_hw_fx = fi(rxMat_hw_noCP, T, F);
    
    rxFFT_hw = complex(zeros(N, numOFDM));
    
    % Hardware Rx (Parallel FFT)
    for symIdx = 1:numOFDM
        coreIdx = mod(symIdx - 1, numCores) + 1;
        dataIn = rxMat_hw_fx(:, symIdx);
        
        hw_out = complex(zeros(N, 1));
        outIdx = 1;
        for i = 1:N
            [dOut, vOut] = fftHW{coreIdx}(dataIn(i), true);
            if vOut, hw_out(outIdx) = dOut; outIdx = outIdx + 1; end
        end
        zero_val = dataIn(1); zero_val(:) = 0;
        while outIdx <= N
            [dOut, vOut] = fftHW{coreIdx}(zero_val, false);
            if vOut, hw_out(outIdx) = dOut; outIdx = outIdx + 1; end
        end
        rxFFT_hw(:, symIdx) = hw_out;
    end
    
    rxFFT_hw_double = double(rxFFT_hw);
    
    % For output plotting
    txSig = txSignal_hw_fi;
    rxSig = rxSignal_hw;
    rxConst = rxFFT_hw_double(:);
    rxConst = rxConst(1:numSymbols);
    
    rxBits_hw = qamdemod(rxConst, M, 'OutputType', 'bit', 'UnitAveragePower', true);
    [~, ber] = biterr(txBits, rxBits_hw);
    
    rxSymIdx_hw = qamdemod(rxConst, M, 'OutputType', 'integer', 'UnitAveragePower', true);
    ser = mean(rxSymIdx_hw ~= txSymIdx);
    
    % Throughput Calculation (for capacity plot)
    frameBits = 1024;
    numFrames = floor(length(txBits) / frameBits);
    if numFrames > 0
        txFrames = reshape(txBits(1:numFrames*frameBits), frameBits, []);
        rxFrames = reshape(rxBits_hw(1:numFrames*frameBits), frameBits, []);
        frameErrors = sum(any(txFrames ~= rxFrames, 1));
        PER = frameErrors / numFrames;
        
        symbolRate = 1e6; % 1 Msps
        maxBitrate = k * symbolRate;
        throughput = maxBitrate * (1 - PER);
    else
        throughput = 0;
    end
end
