function amplitudePattern = optimizedPWAMReceiver(normalizedAmplitude, fileName)
    % PWAM RECEIVER - XCorr + Dynamic Thresholding
    %
    % CONSISTENT APPROACH THROUGHOUT:
    % 1. HYBRID Preamble Detection (XCorr + Edge)
    % 2. Calibration - Weighted Correlation + Dynamic Thresholding
    % 3. Data Length - Weighted Correlation + Dynamic Thresholding
    % 4. Data Extraction - Weighted Correlation + Dynamic Thresholding
    % 5. Soft-Decision Hamming Decoding
    %
    % Two methods shown:
    % - FIXED: Original threshold-based (for comparison - NOT GOOD)
    % - CORRPEAK: Weighted Correlation + Dynamic Thresholding (MAIN METHOD)
    
    fprintf('\n');
    fprintf('╔════════════════════════════════════════════════════════════╗\n');
    fprintf('║  PWAM RECEIVER - XCorr + Dynamic Thresholding              ║\n');
    fprintf('╚════════════════════════════════════════════════════════════╝\n');
    
    %% ==================== STEP 0: TEMPLATE CREATION ====================
    fprintf('\n=== Step 0: Template Creation ===\n');
    
    pulseWidth = estimatePulseWidth(normalizedAmplitude);
    fprintf('Estimated pulse width: %d samples\n', pulseWidth);
    
    pulseTemplate = createPulseTemplate(pulseWidth);
    templateEnergy = sum(pulseTemplate.^2);
    fprintf('Pulse template created (energy: %.4f)\n', templateEnergy);
    
    %% ==================== STEP 1: HYBRID PREAMBLE DETECTION ====================
    % Uses: XCorr (matched filter) + Edge detection
    fprintf('\n=== Step 1: HYBRID Preamble Detection (XCorr + Edge) ===\n');
    
    preambleEndIndex_Edge = findPreambleEdge(normalizedAmplitude);
    [preambleEndIndex_XCorr, ~, ~] = findPreambleXCorr(normalizedAmplitude);
    [preambleEndIndex_Hybrid, ~] = findPreambleHybrid(normalizedAmplitude);
    
    fprintf('Edge-based: %d | XCorr: %d | HYBRID: %d\n', ...
        preambleEndIndex_Edge, preambleEndIndex_XCorr, preambleEndIndex_Hybrid);
    
    preambleEndIndex = preambleEndIndex_Hybrid;
    fprintf('>>> Using HYBRID: %d <<<\n', preambleEndIndex);
    
    if isempty(preambleEndIndex)
        error('Preamble not found.');
    end

    %% ==================== STEP 2: CALIBRATION (XCorr + Dynamic Thresholding) ====================
    % Uses: Weighted Correlation for amplitude extraction, establishes reference levels
    fprintf('\n=== Step 2: Calibration (XCorr + Dynamic Thresholding) ===\n');
    
    calibSegment = normalizedAmplitude(preambleEndIndex+1:end);
    
    % Extract 4 calibration pulses using WEIGHTED CORRELATION
    [calibPositions, calibAmps_Mean, calibAmps_CorrNorm] = ...
        extractPulsesXCorr(calibSegment, pulseTemplate, 4);
    
    fprintf('Calibration pulse positions: [%d, %d, %d, %d]\n', calibPositions);
    fprintf('Calibration amps (Mean):     [%.4f, %.4f, %.4f, %.4f]\n', calibAmps_Mean);
    fprintf('Calibration amps (CorrNorm): [%.4f, %.4f, %.4f, %.4f]\n', calibAmps_CorrNorm);
    
    % Sort calibration amplitudes (descending) - these become reference levels
    [calibAmps_Mean_Sorted, sortIdx] = sort(calibAmps_Mean, 'descend');
    calibAmps_CorrNorm_Sorted = calibAmps_CorrNorm(sortIdx);
    
    % Fixed thresholds (for comparison only)
    thresholds(1) = (calibAmps_Mean_Sorted(1) + calibAmps_Mean_Sorted(2)) / 2;
    thresholds(2) = (calibAmps_Mean_Sorted(2) + calibAmps_Mean_Sorted(3)) / 2;
    thresholds(3) = (calibAmps_Mean_Sorted(3) + calibAmps_Mean_Sorted(4)) / 2;
    thresholds(4) = calibAmps_Mean_Sorted(4) * 0.5;
    
    % Reference levels for Dynamic Thresholding (MAIN)
    referenceLevels_CorrNorm = calibAmps_CorrNorm_Sorted;
    
    fprintf('✓ Fixed Thresholds:         [%.4f, %.4f, %.4f, %.4f]\n', thresholds);
    fprintf('✓ Dynamic Reference Levels: [%.4f, %.4f, %.4f, %.4f]\n', referenceLevels_CorrNorm);
    
    calibrationEndIndex = preambleEndIndex + calibPositions(4) + round(pulseWidth/2);
    fprintf('Calibration end index: %d\n', calibrationEndIndex);
    
    %% ==================== STEP 3: DATA LENGTH (XCorr + Dynamic Thresholding) ====================
    % Uses: Weighted Correlation for pulse detection + Dynamic Thresholding for classification
    fprintf('\n=== Step 3: Data Length (XCorr + Dynamic Thresholding) ===\n');
    
    lenSegment = normalizedAmplitude(calibrationEndIndex+1:end);
    
    % Extract 4 length pulses using WEIGHTED CORRELATION
    [lenPositions, lenAmps_Mean, lenAmps_CorrNorm] = extractPulsesXCorr(lenSegment, pulseTemplate, 4);
    
    fprintf('Length pulse positions: [%d, %d, %d, %d]\n', lenPositions);
    fprintf('Length amps (CorrNorm): [%.4f, %.4f, %.4f, %.4f]\n', lenAmps_CorrNorm);
    
    % Classify using DYNAMIC THRESHOLDING
    [lenPattern, lenConfidence] = classifyDynamicThreshold(lenAmps_CorrNorm, referenceLevels_CorrNorm);
    
    fprintf('Length pattern (Dynamic): '); fprintf('%d ', lenPattern); fprintf('\n');
    fprintf('Length confidence:        '); fprintf('%.0f%% ', lenConfidence*100); fprintf('\n');
    fprintf('Avg length confidence: %.2f%%\n', mean(lenConfidence)*100);
    
    % Convert to binary and calculate data length
    lenBinary = amplitudeToBinary(lenPattern);
    fprintf('Length binary: %s\n', lenBinary);
    
    dataLengthDec = binaryToDecimal(lenBinary - '0');
    dataLength = floor(dataLengthDec / 14) * 14;
    if dataLength == 0
        dataLength = 14;
    end
    
    lenEndIndex = calibrationEndIndex + lenPositions(4) + round(pulseWidth/2);
    fprintf('Data length: %d bits (%d pulses)\n', dataLength, dataLength/2);
    fprintf('Length field end index: %d\n', lenEndIndex);
    
    %% ==================== STEP 4: DATA EXTRACTION (XCorr + Dynamic Thresholding) ====================
    % Uses: Weighted Correlation for pulse detection + Dynamic Thresholding for classification
    fprintf('\n=== Step 4: Data Extraction (XCorr + Dynamic Thresholding) ===\n');
    
    dataSegment = normalizedAmplitude(lenEndIndex:end);
    numDataPulses = floor(dataLength / 2);
    
    % Extract data pulses using WEIGHTED CORRELATION
    [dataPositions, dataAmps_Mean, dataAmps_CorrNorm] = ...
        extractPulsesXCorr(dataSegment, pulseTemplate, numDataPulses);
    
    fprintf('Extracted %d data pulses\n', length(dataAmps_Mean));
    fprintf('Data pulse positions: '); fprintf('%d ', dataPositions); fprintf('\n');
    fprintf('Data amps (Mean):     '); fprintf('%.4f ', dataAmps_Mean); fprintf('\n');
    fprintf('Data amps (CorrNorm): '); fprintf('%.4f ', dataAmps_CorrNorm); fprintf('\n');
    
    %% ==================== STEP 5: CLASSIFICATION ====================
    fprintf('\n=== Step 5: Classification ===\n');
    
    % ----- Method 1: FIXED Thresholds (for comparison - NOT RECOMMENDED) -----
    fprintf('\n--- Method 1: FIXED Thresholds (for comparison only) ---\n');
    pattern_Fixed = classifyFixedThreshold(dataAmps_Mean, thresholds);
    fprintf('Fixed pattern: '); fprintf('%d ', pattern_Fixed); fprintf('\n');
    fprintf('⚠ Fixed thresholds do NOT adapt to signal variations!\n');
    
    % ----- Method 2: CORRPEAK + Dynamic Thresholding (MAIN METHOD) -----
    fprintf('\n--- Method 2: CORRPEAK + Dynamic Thresholding (MAIN) ---\n');
    [pattern_CorrPeak, confidence_CorrPeak] = classifyDynamicThreshold(dataAmps_CorrNorm, referenceLevels_CorrNorm);
    fprintf('CorrPeak pattern:   '); fprintf('%d ', pattern_CorrPeak); fprintf('\n');
    fprintf('CorrPeak confidence: '); fprintf('%.0f%% ', confidence_CorrPeak*100); fprintf('\n');
    fprintf('Avg confidence: %.2f%%\n', mean(confidence_CorrPeak) * 100);
    
    % ----- Comparison Table -----
    fprintf('\n--- Comparison: Fixed vs CorrPeak ---\n');
    fprintf('Pulse | Fixed | CorrPeak | Confidence | Match?\n');
    fprintf('------+-------+----------+------------+-------\n');
    for i = 1:length(pattern_Fixed)
        if pattern_Fixed(i) == pattern_CorrPeak(i)
            matchStr = '✓';
        else
            matchStr = '✗ DIFFER';
        end
        fprintf('  %d   |  %3d  |   %3d    |   %5.1f%%   | %s\n', ...
            i, pattern_Fixed(i), pattern_CorrPeak(i), confidence_CorrPeak(i)*100, matchStr);
    end
    
    % Use CorrPeak as the final result
    amplitudePattern = pattern_CorrPeak;
    fprintf('\n>>> Using CORRPEAK + Dynamic Thresholding <<<\n');
    fprintf('>>> Avg Confidence: %.1f%% <<<\n', mean(confidence_CorrPeak)*100);
    
    %% ==================== STEP 6: BINARY CONVERSION ====================
    fprintf('\n=== Step 6: Binary Conversion ===\n');
    
    binaryPattern = amplitudeToBinary(amplitudePattern);
    fprintf('Binary Pattern: %s\n', binaryPattern);
    
    % Convert symbol confidence to bit confidence for soft decoding
    bitConfidences = symbolToBitConfidence(confidence_CorrPeak);
    fprintf('Bit confidences: '); fprintf('%.2f ', bitConfidences); fprintf('\n');
    
    %% ==================== STEP 7: SOFT-DECISION HAMMING DECODING ====================
    fprintf('\n=== Step 7: Soft-Decision Hamming Decoding ===\n');
    
    [decodedText, decodedBits, BER, softCorrections] = hammingSoftDecode(binaryPattern, bitConfidences, fileName);
    
    %% ==================== FINAL OUTPUT ====================
    fprintf('\n');
    fprintf('╔════════════════════════════════════════════════════════════╗\n');
    fprintf('║  DECODED TEXT: %-43s ║\n', decodedText);
    fprintf('║  BER: %.6f                                             ║\n', BER);
    fprintf('║  Soft Corrections: %d                                       ║\n', softCorrections);
    fprintf('╚════════════════════════════════════════════════════════════╝\n');
    
    %% ==================== SUMMARY ====================
    fprintf('\n');
    fprintf('╔════════════════════════════════════════════════════════════╗\n');
    fprintf('║                METHOD SUMMARY                              ║\n');
    fprintf('╠════════════════════════════════════════════════════════════╣\n');
    fprintf('║ Step 1 - Preamble:    HYBRID (XCorr + Edge)                ║\n');
    fprintf('║ Step 2 - Calibration: XCorr + Dynamic Thresholding         ║\n');
    fprintf('║ Step 3 - Data Length: XCorr + Dynamic Thresholding         ║\n');
    fprintf('║ Step 4 - Data:        XCorr + Dynamic Thresholding         ║\n');
    fprintf('║ Step 7 - Decoding:    Soft-Decision Hamming                ║\n');
    fprintf('╠════════════════════════════════════════════════════════════╣\n');
    fprintf('║ XCorr Confidence: %.1f%%                                    ║\n', mean(confidence_CorrPeak)*100);
    fprintf('║ BER: %.6f                                              ║\n', BER);
    fprintf('╚════════════════════════════════════════════════════════════╝\n');
    
    %% Visualization
    plotResults(dataSegment, dataPositions, dataAmps_CorrNorm, ...
        referenceLevels_CorrNorm, pattern_Fixed, pattern_CorrPeak, ...
        confidence_CorrPeak, pulseTemplate);
end

%% ==================== PULSE EXTRACTION WITH WEIGHTED CORRELATION ====================

function [pulsePositions, pulseAmps_Mean, pulseAmps_CorrNorm] = extractPulsesXCorr(signal, pulseTemplate, maxPulses)
    % PULSE EXTRACTION USING CROSS-CORRELATION
    %
    % Two amplitude measurements:
    % 1. pulseAmps_Mean: Standard mean amplitude (for Fixed threshold comparison)
    % 2. pulseAmps_CorrNorm: WEIGHTED correlation amplitude (Main Method)
    %
    % Peak finding uses STANDARD correlation (unchanged from original)
    % Only amplitude estimation uses WEIGHTED correlation
    
    signal = signal(:);
    pulseTemplate = pulseTemplate(:);
    pulseWidth = length(pulseTemplate);
    templateEnergy = sum(pulseTemplate.^2);
    
    % ===== STANDARD CROSS-CORRELATION (for peak finding) =====
    correlationSignal_Standard = conv(signal, flipud(pulseTemplate), 'same');
    corrNormalized = correlationSignal_Standard / max(abs(correlationSignal_Standard));
    
    % ===== FIND PEAKS (Pulse Locations) - UNCHANGED =====
    minPeakHeight = 0.2;
    minPeakDistance = round(pulseWidth * 0.7);
    
    [~, locs] = findpeaks(corrNormalized, 'MinPeakHeight', minPeakHeight, ...
        'MinPeakDistance', minPeakDistance);
    
    numPulses = min(length(locs), maxPulses);
    pulsePositions = locs(1:numPulses);
    
    % ===== WEIGHTED CORRELATION (for amplitude estimation only) =====
    % Create Gaussian weight window
    sigma = pulseWidth / 4;  % Standard deviation
    x = linspace(-pulseWidth/2, pulseWidth/2, pulseWidth);
    gaussianWeight = exp(-x.^2 / (2 * sigma^2));
    gaussianWeight = gaussianWeight(:);
    
    % Apply weight to template
    weightedTemplate = pulseTemplate .* gaussianWeight;
    weightedEnergy = sum(weightedTemplate.^2);
    
    % Weighted correlation signal
    correlationSignal_Weighted = conv(signal, flipud(weightedTemplate), 'same');
    
    halfWidth = round(pulseWidth / 2);
    
    pulseAmps_Mean = zeros(numPulses, 1);
    pulseAmps_CorrNorm = zeros(numPulses, 1);
    
    for i = 1:numPulses
        pos = pulsePositions(i);
        
        % ===== MEAN AMPLITUDE (for Fixed threshold - UNCHANGED) =====
        startIdx = max(1, pos - halfWidth);
        endIdx = min(length(signal), pos + halfWidth);
        pulseAmps_Mean(i) = mean(signal(startIdx:endIdx));
        
        % ===== WEIGHTED CORRELATION AMPLITUDE (Main Method) =====
        % Use parabolic interpolation for sub-sample accuracy
        if pos > 1 && pos < length(correlationSignal_Weighted)
            y1 = correlationSignal_Weighted(pos - 1);
            y2 = correlationSignal_Weighted(pos);
            y3 = correlationSignal_Weighted(pos + 1);
            
            denom = y1 - 2*y2 + y3;
            if abs(denom) > 1e-10
                delta = 0.5 * (y1 - y3) / denom;
                peakValue = y2 - 0.25 * (y1 - y3) * delta;
            else
                peakValue = y2;
            end
            pulseAmps_CorrNorm(i) = peakValue / weightedEnergy;
        else
            pulseAmps_CorrNorm(i) = correlationSignal_Weighted(pos) / weightedEnergy;
        end
    end
end

%% ==================== DYNAMIC THRESHOLDING CLASSIFICATION ====================

function [pattern, confidence] = classifyDynamicThreshold(amplitudes, referenceLevels)
    % CONFIDENCE-WEIGHTED UPDATE DYNAMIC THRESHOLDING
    %
    % This method ADAPTS reference levels as it processes pulses:
    % 1. Classify each pulse using current reference levels
    % 2. If confidence is HIGH, slightly update the reference level
    %    towards the measured amplitude
    % 3. This allows the receiver to track slow drift in signal levels
    %
    % Update rule: ref_new = ref_old + alpha * conf * (amp - ref_old)
    % - alpha: learning rate (small, e.g., 0.15)
    % - conf: confidence (only update when confident)
    % - (amp - ref_old): error term
    %
    % Benefits:
    % - Tracks slow amplitude drift
    % - Self-correcting: high-confidence decisions reinforce good references
    % - Low-confidence decisions don't corrupt references
    
    symbolValues = [210, 160, 110, 60];  % Symbol mapping (descending order)
    alpha = 0.15;           % Learning rate
    confThreshold = 0.7;    % Only update if confidence above this
    
    amplitudes = amplitudes(:);
    currentRefs = referenceLevels(:)';  % Working copy of references
    
    numPulses = length(amplitudes);
    pattern = zeros(numPulses, 1);
    confidence = zeros(numPulses, 1);
    
    for i = 1:numPulses
        amp = amplitudes(i);
        
        % ===== CALCULATE DISTANCES TO CURRENT REFERENCES =====
        distances = abs(amp - currentRefs);
        
        % ===== FIND CLOSEST REFERENCE =====
        [minDist, closestIdx] = min(distances);
        pattern(i) = symbolValues(closestIdx);
        
        % ===== CALCULATE CONFIDENCE =====
        sortedDist = sort(distances);
        d1 = sortedDist(1);  % Closest
        d2 = sortedDist(2);  % Second closest
        
        if d1 + d2 > 0
            confidence(i) = 1 - (d1 / (d1 + d2));
        else
            confidence(i) = 1;
        end
        
        % ===== UPDATE REFERENCE IF CONFIDENCE IS HIGH =====
        if confidence(i) >= confThreshold
            % Update only the closest reference
            error = amp - currentRefs(closestIdx);
            update = alpha * confidence(i) * error;
            currentRefs(closestIdx) = currentRefs(closestIdx) + update;
        end
        
        % Flag low confidence pulses
        if confidence(i) < 0.6
            fprintf('  ⚠ Pulse %d: amp=%.4f, closest=%d (dist=%.4f), conf=%.1f%% LOW\n', ...
                i, amp, pattern(i), minDist, confidence(i)*100);
        end
    end
end

function pattern = classifyFixedThreshold(amplitudes, thresholds)
    % FIXED THRESHOLD CLASSIFICATION (for comparison only)
    % Uses predetermined threshold values - does NOT adapt to signal variations
    
    amplitudes = amplitudes(:);
    pattern = zeros(length(amplitudes), 1);
    
    for i = 1:length(amplitudes)
        if amplitudes(i) >= thresholds(1)
            pattern(i) = 210;
        elseif amplitudes(i) >= thresholds(2)
            pattern(i) = 160;
        elseif amplitudes(i) >= thresholds(3)
            pattern(i) = 110;
        else
            pattern(i) = 60;
        end
    end
end

%% ==================== SOFT-DECISION HAMMING DECODING ====================

function [decodedText, decodedBits, BER, numCorrections] = hammingSoftDecode(encodedBinary, bitConfidences, fileName)
    % SOFT-DECISION HAMMING DECODING
    %
    % Uses bit confidence values to make smarter error correction:
    % - Standard Hamming finds error position via syndrome
    % - Soft-decision checks if that position has low confidence
    % - Warns about potential double errors when confidences don't match
    
    if mod(length(encodedBinary), 7) ~= 0
        error('Binary length must be multiple of 7');
    end
    
    % Hamming(7,4) parity check matrix
    H = [1 0 1 0 1 0 1; 
         0 1 1 0 0 1 1; 
         0 0 0 1 1 1 1];
    
    decodedBits = [];
    numCorrections = 0;
    
    numCodewords = length(encodedBinary) / 7;
    
    fprintf('Soft-Decision Decoding:\n');
    
    for i = 1:numCodewords
        startIdx = (i-1)*7 + 1;
        endIdx = i*7;
        
        codeword = encodedBinary(startIdx:endIdx) - '0';
        codeConfidence = bitConfidences(startIdx:endIdx);
        
        % Calculate syndrome
        syndrome = mod(codeword * H', 2);
        errIdx = binaryToDecimal(flip(syndrome));
        
        if errIdx > 0
            numCorrections = numCorrections + 1;
            
            % Soft-decision analysis
            [minConf, leastConfidentIdx] = min(codeConfidence);
            hammingConf = codeConfidence(errIdx);
            
            fprintf('  Codeword %d: Syndrome points to pos %d (conf %.0f%%)\n', i, errIdx, hammingConf*100);
            fprintf('              Least confident: pos %d (conf %.0f%%)\n', leastConfidentIdx, minConf*100);
            
            % Check for potential issues
            if hammingConf > 0.8 && minConf < 0.5 && leastConfidentIdx ~= errIdx
                fprintf('              ⚠ WARNING: Confidence mismatch - possible double error\n');
            end
            
            % Apply Hamming correction
            codeword(errIdx) = mod(codeword(errIdx) + 1, 2);
            fprintf('              → Corrected position %d\n', errIdx);
        end
        
        % Extract data bits (positions 3, 5, 6, 7 in Hamming(7,4))
        decodedBits = [decodedBits, codeword(3), codeword(5), codeword(6), codeword(7)];
    end
    
    % Calculate BER
    [~, name, ~] = fileparts(fileName);
    refBinary = '';
    for i = 1:length(name)
        refBinary = [refBinary, dec2bin(double(name(i)), 8)];
    end
    
    decodedStr = sprintf('%d', decodedBits);
    minLen = min(length(refBinary), length(decodedStr));
    BER = sum((decodedStr(1:minLen) - '0') ~= (refBinary(1:minLen) - '0')) / minLen;
    
    fprintf('Reference binary: %s\n', refBinary);
    fprintf('Decoded binary:   %s\n', decodedStr);
    fprintf('BER: %.6f, Corrections: %d\n', BER, numCorrections);
    
    % Convert to text
    decodedText = '';
    for i = 1:floor(length(decodedBits)/8)
        byte = decodedBits((i-1)*8+1 : i*8);
        decodedText = [decodedText, char(binaryToDecimal(byte))];
    end
end

function bitConfidences = symbolToBitConfidence(symbolConfidences)
    % Convert symbol confidences to bit confidences
    % Each symbol maps to 2 bits, both get the same confidence
    
    numSymbols = length(symbolConfidences);
    bitConfidences = zeros(1, numSymbols * 2);
    
    for i = 1:numSymbols
        bitConfidences(2*i - 1) = symbolConfidences(i);
        bitConfidences(2*i) = symbolConfidences(i);
    end
end

%% ==================== HYBRID PREAMBLE DETECTION ====================

function [preambleEndIndex, searchRegion] = findPreambleHybrid(signal)
    % HYBRID PREAMBLE DETECTION
    % Combines XCorr (robust) with Edge detection (precise)
    
    [xcorrEnd, ~, pulseWidth] = findPreambleXCorr(signal);
    margin = pulseWidth * 3;
    searchRegion = [max(1, xcorrEnd - margin), min(length(signal), xcorrEnd + margin)];
    
    edgeResult = findPreambleEdge(signal);
    if ~isempty(edgeResult) && edgeResult >= searchRegion(1) - margin && edgeResult <= searchRegion(2) + margin
        preambleEndIndex = edgeResult;
    else
        preambleEndIndex = xcorrEnd - round(pulseWidth/2);
    end
end

function [preambleEndIndex, correlation, pulseWidth] = findPreambleXCorr(signal)
    % PREAMBLE DETECTION USING XCORR
    % Correlates signal with preamble template (4 pulses)
    
    signal = signal(:);
    pulseWidth = estimatePulseWidth(signal);
    template = createPreambleTemplate(pulseWidth);
    
    [correlation, lags] = xcorr(signal, template(:));
    correlation = correlation(lags >= 0);
    
    [~, maxIdx] = max(correlation);
    preambleEndIndex = maxIdx + length(template) - 1;
    preambleEndIndex = min(preambleEndIndex, length(signal) - 1);
end

function preambleEndIndex = findPreambleEdge(signal)
    % PREAMBLE DETECTION USING EDGE DETECTION
    % Finds 4 consecutive high-amplitude pulses
    
    signal = signal(:);
    maxAmp = max(signal);
    expectedAmp = 0.5 * maxAmp;
    minRise = 0.01 * maxAmp;
    
    risingEdges = find(diff(signal) > minRise);
    validCount = 0; i = 1;
    
    while i <= length(risingEdges) - 1
        startIdx = risingEdges(i);
        
        peakIdx = startIdx + 1;
        while peakIdx < length(signal) && signal(peakIdx) >= signal(peakIdx-1)
            peakIdx = peakIdx + 1;
        end
        
        endIdx = peakIdx;
        while endIdx < length(signal) && signal(endIdx) <= signal(endIdx-1)
            endIdx = endIdx + 1;
        end
        
        if max(signal(startIdx:endIdx)) >= expectedAmp
            validCount = validCount + 1;
            if validCount == 4
                preambleEndIndex = endIdx - 1;
                return;
            end
            while i <= length(risingEdges) && risingEdges(i) < endIdx
                i = i + 1;
            end
        else
            i = i + 1;
        end
    end
    preambleEndIndex = [];
end

function template = createPreambleTemplate(pulseWidth)
    % Create 4-pulse preamble template
    t = linspace(0, pi, pulseWidth);
    singlePulse = (1 - cos(t)) / 2;
    gap = zeros(1, round(pulseWidth * 0.5));
    
    template = [];
    for i = 1:4
        template = [template, singlePulse, gap];
    end
    template = template / max(template);
end

%% ==================== HELPER FUNCTIONS ====================

function template = createPulseTemplate(pulseWidth)
    % Create raised-cosine pulse template with unit energy
    t = linspace(0, pi, pulseWidth);
    template = (1 - cos(t)) / 2;
    template = template / sqrt(sum(template.^2));
end

function pulseWidth = estimatePulseWidth(signal)
    signal = signal(:);
    threshold = 0.01;
    rising = false; falling = false;
    startIdx = 1; pulseWidths = [];
    
    maxSamples = min(length(signal), 300);
    
    for i = 2:maxSamples - 1
        if (signal(i) - signal(i-1)) > threshold && ~rising && ~falling
            rising = true; startIdx = i - 1;
        end
        if rising && (signal(i) - signal(i+1)) >= threshold
            rising = false; falling = true;
        end
        if falling && (signal(i+1) - signal(i)) > threshold
            pulseWidths = [pulseWidths, i - startIdx];
            falling = false;
            if length(pulseWidths) >= 4, break; end
        end
    end
    
    if ~isempty(pulseWidths)
        pulseWidth = round(mean(pulseWidths));
    else
        pulseWidth = 15;
    end
    pulseWidth = max(5, min(50, pulseWidth));
end

function binaryString = amplitudeToBinary(amplitudeArray)
    binaryString = '';
    for i = 1:length(amplitudeArray)
        switch amplitudeArray(i)
            case 210, binaryString = [binaryString, '10'];
            case 160, binaryString = [binaryString, '11'];
            case 110,  binaryString = [binaryString, '01'];
            case 60,  binaryString = [binaryString, '00'];
        end
    end
end

function decVal = binaryToDecimal(binArray)
    decVal = sum(binArray .* 2.^(length(binArray)-1:-1:0));
end

%% ==================== VISUALIZATION ====================

function plotResults(dataSegment, dataPositions, dataAmps_CorrNorm, ...
        refLevels_CorrNorm, pattern_Fixed, pattern_CorrPeak, ...
        confidence_CorrPeak, pulseTemplate)
    
    figure('Name', 'PWAM Receiver - XCorr + Dynamic Thresholding', 'Position', [50 50 1400 800]);
    
    colors = {'r', 'm', 'c', 'b'};
    symbolMap = [210, 160, 110, 60];
    
    % Plot 1: Signal with Detected Pulses
    subplot(2,3,1);
    plot(dataSegment, 'b-', 'LineWidth', 1);
    hold on;
    validPos = dataPositions(dataPositions <= length(dataSegment));
    if ~isempty(validPos)
        plot(validPos, dataSegment(validPos), 'ro', 'MarkerSize', 10, 'LineWidth', 2);
    end
    xlabel('Sample'); ylabel('Amplitude');
    title('Signal with Pulse Locations (XCorr)');
    legend('Signal', 'Detected Pulses');
    grid on;
    
    % Plot 2: Matched Filter Output
    subplot(2,3,2);
    corrSignal = conv(dataSegment(:), flipud(pulseTemplate(:)), 'same');
    plot(corrSignal, 'r-', 'LineWidth', 1);
    hold on;
    if ~isempty(validPos)
        plot(validPos, corrSignal(validPos), 'go', 'MarkerSize', 10, 'LineWidth', 2);
    end
    xlabel('Sample'); ylabel('Correlation');
    title('Cross-Correlation (Matched Filter)');
    legend('Correlation', 'Peaks');
    grid on;
    
    % Plot 3: CorrNorm Amplitudes vs Reference Levels
    subplot(2,3,3);
    bar(dataAmps_CorrNorm, 'FaceColor', [0.3 0.6 0.9]);
    hold on;
    for j = 1:4
        yline(refLevels_CorrNorm(j), '--', 'Color', colors{j}, 'LineWidth', 2);
    end
    xlabel('Pulse'); ylabel('CorrNorm Amplitude');
    title('Amplitudes vs Dynamic Reference Levels');
    legend('Amplitude', '210 ref', '160 ref', '110 ref', '60 ref', 'Location', 'best');
    grid on;
    
    % Plot 4: Fixed vs CorrPeak Classification
    subplot(2,3,4);
    patternIdx_Fixed = arrayfun(@(x) find(symbolMap == x, 1), pattern_Fixed);
    patternIdx_CorrPeak = arrayfun(@(x) find(symbolMap == x, 1), pattern_CorrPeak);
    
    x = 1:length(pattern_Fixed);
    bar(x - 0.15, patternIdx_Fixed, 0.3, 'FaceColor', [0.8 0.2 0.2]);
    hold on;
    bar(x + 0.15, patternIdx_CorrPeak, 0.3, 'FaceColor', [0.2 0.7 0.2]);
    ylim([0.5 4.5]);
    yticks(1:4); yticklabels({'210', '160', '110', '60'});
    xlabel('Pulse'); ylabel('Symbol');
    title('Classification: Fixed vs CorrPeak');
    legend('Fixed (Bad)', 'CorrPeak (Good)');
    grid on;
    
    % Plot 5: Confidence per Pulse
    subplot(2,3,5);
    bar(confidence_CorrPeak * 100, 'FaceColor', [0.2 0.7 0.2]);
    hold on;
    yline(60, 'r--', 'LineWidth', 2);
    yline(80, 'g--', 'LineWidth', 2);
    xlabel('Pulse'); ylabel('Confidence (%)');
    title('Dynamic Thresholding Confidence');
    ylim([0 100]);
    legend('Confidence', 'Low (60%)', 'Good (80%)');
    grid on;
    
    % Plot 6: Method Summary
    subplot(2,3,6);
    axis off;
    
    text(0.05, 0.95, 'METHOD SUMMARY', 'FontSize', 14, 'FontWeight', 'bold');
    
    text(0.05, 0.80, 'CROSS-CORRELATION (XCorr):', 'FontSize', 11, 'FontWeight', 'bold', 'Color', 'blue');
    text(0.05, 0.72, '• Matched filter: conv(signal, flip(template))', 'FontSize', 9);
    text(0.05, 0.64, '• Peak location → pulse position', 'FontSize', 9);
    text(0.05, 0.56, '• Peak value / energy → amplitude', 'FontSize', 9);
    
    text(0.05, 0.44, 'DYNAMIC THRESHOLDING:', 'FontSize', 11, 'FontWeight', 'bold', 'Color', [0 0.5 0]);
    text(0.05, 0.36, '• Distance to all 4 reference levels', 'FontSize', 9);
    text(0.05, 0.28, '• Closest reference = symbol', 'FontSize', 9);
    text(0.05, 0.20, '• Confidence = 1 - d1/(d1+d2)', 'FontSize', 9);
    
    text(0.05, 0.06, sprintf('Avg Confidence: %.1f%%', mean(confidence_CorrPeak)*100), ...
        'FontSize', 12, 'FontWeight', 'bold', 'Color', [0 0.5 0]);
    
    sgtitle('PWAM Receiver: XCorr + Dynamic Thresholding');
end