function amplitudePattern = XCorr_comparison(normalizedAmplitude, fileName)
    % PWAM RECEIVER - XCorr Optimization Comparison
    %
    % COMPARING 3 CROSS-CORRELATION OPTIMIZATION METHODS:
    % 1. WEIGHTED CORRELATION - Weight center samples more heavily
    % 2. MULTI-SCALE MF - Use multiple template widths
    % 3. PHASE-AWARE CORRELATION - Use phase information from analytic signal
    %
    % All methods use Dynamic Thresholding for classification
    
    fprintf('\n');
    fprintf('╔════════════════════════════════════════════════════════════╗\n');
    fprintf('║  PWAM RECEIVER - XCorr Optimization Comparison             ║\n');
    fprintf('╚════════════════════════════════════════════════════════════╝\n');
    
    %% ==================== STEP 0: TEMPLATE CREATION ====================
    fprintf('\n=== Step 0: Template Creation ===\n');
    
    pulseWidth = estimatePulseWidth(normalizedAmplitude);
    fprintf('Estimated pulse width: %d samples\n', pulseWidth);
    
    pulseTemplate = createPulseTemplate(pulseWidth);
    templateEnergy = sum(pulseTemplate.^2);
    fprintf('Pulse template created (energy: %.4f)\n', templateEnergy);
    
    %% ==================== STEP 1: HYBRID PREAMBLE DETECTION ====================
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

    %% ==================== STEP 2: CALIBRATION ====================
    fprintf('\n=== Step 2: Calibration ===\n');
    
    calibSegment = normalizedAmplitude(preambleEndIndex+1:end);
    
    % Use standard XCorr for calibration (baseline)
    [calibPositions, calibAmps_Mean, calibAmps_Standard] = ...
        extractPulsesXCorr_Standard(calibSegment, pulseTemplate, 4);
    
    % Also extract with all 3 methods for comparison
    [~, ~, calibAmps_Weighted] = extractPulsesXCorr_Weighted(calibSegment, pulseTemplate, 4);
    [~, ~, calibAmps_MultiScale] = extractPulsesXCorr_MultiScale(calibSegment, pulseTemplate, 4);
    [~, ~, calibAmps_Phase] = extractPulsesXCorr_PhaseAware(calibSegment, pulseTemplate, 4);
    
    fprintf('Calibration pulse positions: [%d, %d, %d, %d]\n', calibPositions);
    fprintf('Calibration amps (Standard):   [%.4f, %.4f, %.4f, %.4f]\n', calibAmps_Standard);
    fprintf('Calibration amps (Weighted):   [%.4f, %.4f, %.4f, %.4f]\n', calibAmps_Weighted);
    fprintf('Calibration amps (MultiScale): [%.4f, %.4f, %.4f, %.4f]\n', calibAmps_MultiScale);
    fprintf('Calibration amps (Phase):      [%.4f, %.4f, %.4f, %.4f]\n', calibAmps_Phase);
    
    % Sort calibration amplitudes for each method
    [~, sortIdx] = sort(calibAmps_Mean, 'descend');
    
    refLevels_Standard = calibAmps_Standard(sortIdx);
    refLevels_Weighted = calibAmps_Weighted(sortIdx);
    refLevels_MultiScale = calibAmps_MultiScale(sortIdx);
    refLevels_Phase = calibAmps_Phase(sortIdx);
    
    % Fixed thresholds for comparison
    calibAmps_Mean_Sorted = calibAmps_Mean(sortIdx);
    thresholds(1) = (calibAmps_Mean_Sorted(1) + calibAmps_Mean_Sorted(2)) / 2;
    thresholds(2) = (calibAmps_Mean_Sorted(2) + calibAmps_Mean_Sorted(3)) / 2;
    thresholds(3) = (calibAmps_Mean_Sorted(3) + calibAmps_Mean_Sorted(4)) / 2;
    thresholds(4) = calibAmps_Mean_Sorted(4) * 0.5;
    
    fprintf('\n--- Reference Levels (sorted) ---\n');
    fprintf('Standard:   [%.4f, %.4f, %.4f, %.4f]\n', refLevels_Standard);
    fprintf('Weighted:   [%.4f, %.4f, %.4f, %.4f]\n', refLevels_Weighted);
    fprintf('MultiScale: [%.4f, %.4f, %.4f, %.4f]\n', refLevels_MultiScale);
    fprintf('Phase:      [%.4f, %.4f, %.4f, %.4f]\n', refLevels_Phase);
    
    calibrationEndIndex = preambleEndIndex + calibPositions(4) + round(pulseWidth/2);
    fprintf('Calibration end index: %d\n', calibrationEndIndex);
    
    %% ==================== STEP 3: DATA LENGTH ====================
    fprintf('\n=== Step 3: Data Length ===\n');
    
    lenSegment = normalizedAmplitude(calibrationEndIndex+1:end);
    
    % Use standard method for length (consistent)
    [lenPositions, ~, lenAmps_Standard] = extractPulsesXCorr_Standard(lenSegment, pulseTemplate, 4);
    [lenPattern, ~] = classifyDynamicThreshold(lenAmps_Standard, refLevels_Standard);
    
    fprintf('Length pattern: '); fprintf('%d ', lenPattern); fprintf('\n');
    
    lenBinary = amplitudeToBinary(lenPattern);
    fprintf('Length binary: %s\n', lenBinary);
    
    dataLengthDec = binaryToDecimal(lenBinary - '0');
    dataLength = floor(dataLengthDec / 14) * 14;
    if dataLength == 0
        dataLength = 14;
    end
    
    lenEndIndex = calibrationEndIndex + lenPositions(4) + round(pulseWidth/2);
    fprintf('Data length: %d bits (%d pulses)\n', dataLength, dataLength/2);
    
    %% ==================== STEP 4: DATA EXTRACTION WITH ALL 3 METHODS ====================
    fprintf('\n=== Step 4: Data Extraction (All 3 Methods) ===\n');
    
    dataSegment = normalizedAmplitude(lenEndIndex:end);
    numDataPulses = floor(dataLength / 2);
    
    % Method 0: Standard XCorr (Baseline)
    fprintf('\n--- Method 0: STANDARD XCorr (Baseline) ---\n');
    [dataPositions, dataAmps_Mean, dataAmps_Standard] = ...
        extractPulsesXCorr_Standard(dataSegment, pulseTemplate, numDataPulses);
    fprintf('Standard amps: '); fprintf('%.4f ', dataAmps_Standard); fprintf('\n');
    
    % Method 1: Weighted Correlation
    fprintf('\n--- Method 1: WEIGHTED Correlation ---\n');
    [~, ~, dataAmps_Weighted, weightedCorrSignal] = ...
        extractPulsesXCorr_Weighted(dataSegment, pulseTemplate, numDataPulses);
    fprintf('Weighted amps: '); fprintf('%.4f ', dataAmps_Weighted); fprintf('\n');
    
    % Method 2: Multi-Scale Matched Filter
    fprintf('\n--- Method 2: MULTI-SCALE Matched Filter ---\n');
    [~, ~, dataAmps_MultiScale, multiScaleInfo] = ...
        extractPulsesXCorr_MultiScale(dataSegment, pulseTemplate, numDataPulses);
    fprintf('MultiScale amps: '); fprintf('%.4f ', dataAmps_MultiScale); fprintf('\n');
    
    % Method 3: Phase-Aware Correlation
    fprintf('\n--- Method 3: PHASE-AWARE Correlation ---\n');
    [~, ~, dataAmps_Phase, phaseInfo] = ...
        extractPulsesXCorr_PhaseAware(dataSegment, pulseTemplate, numDataPulses);
    fprintf('Phase amps: '); fprintf('%.4f ', dataAmps_Phase); fprintf('\n');
    
    %% ==================== STEP 5: CLASSIFICATION WITH ALL METHODS ====================
    fprintf('\n=== Step 5: Classification (All Methods) ===\n');
    
    % Fixed threshold (for reference)
    pattern_Fixed = classifyFixedThreshold(dataAmps_Mean, thresholds);
    
    % Standard XCorr + Dynamic Thresholding
    [pattern_Standard, conf_Standard] = classifyDynamicThreshold(dataAmps_Standard, refLevels_Standard);
    
    % Weighted + Dynamic Thresholding
    [pattern_Weighted, conf_Weighted] = classifyDynamicThreshold(dataAmps_Weighted, refLevels_Weighted);
    
    % MultiScale + Dynamic Thresholding
    [pattern_MultiScale, conf_MultiScale] = classifyDynamicThreshold(dataAmps_MultiScale, refLevels_MultiScale);
    
    % Phase-Aware + Dynamic Thresholding
    [pattern_Phase, conf_Phase] = classifyDynamicThreshold(dataAmps_Phase, refLevels_Phase);
    
    %% ==================== RESULTS COMPARISON ====================
    fprintf('\n');
    fprintf('╔════════════════════════════════════════════════════════════╗\n');
    fprintf('║              CLASSIFICATION COMPARISON                     ║\n');
    fprintf('╚════════════════════════════════════════════════════════════╝\n');
    
    fprintf('\n--- Pattern Comparison ---\n');
    fprintf('Pulse | Fixed | Standard | Weighted | MultiScale | Phase\n');
    fprintf('------+-------+----------+----------+------------+-------\n');
    for i = 1:length(pattern_Fixed)
        fprintf('  %d   |  %3d  |   %3d    |   %3d    |    %3d     |  %3d\n', ...
            i, pattern_Fixed(i), pattern_Standard(i), pattern_Weighted(i), ...
            pattern_MultiScale(i), pattern_Phase(i));
    end
    
    fprintf('\n--- Confidence Comparison ---\n');
    fprintf('Pulse | Standard | Weighted | MultiScale | Phase\n');
    fprintf('------+----------+----------+------------+-------\n');
    for i = 1:length(conf_Standard)
        fprintf('  %d   |  %5.1f%%  |  %5.1f%%  |   %5.1f%%   | %5.1f%%\n', ...
            i, conf_Standard(i)*100, conf_Weighted(i)*100, ...
            conf_MultiScale(i)*100, conf_Phase(i)*100);
    end
    
    fprintf('\n--- Average Confidence ---\n');
    fprintf('Standard:   %.2f%%\n', mean(conf_Standard)*100);
    fprintf('Weighted:   %.2f%%\n', mean(conf_Weighted)*100);
    fprintf('MultiScale: %.2f%%\n', mean(conf_MultiScale)*100);
    fprintf('Phase:      %.2f%%\n', mean(conf_Phase)*100);
    
    %% ==================== DECODE WITH ALL METHODS ====================
    fprintf('\n');
    fprintf('╔════════════════════════════════════════════════════════════╗\n');
    fprintf('║                    DECODING RESULTS                        ║\n');
    fprintf('╚════════════════════════════════════════════════════════════╝\n');
    
    % Decode Standard
    binary_Standard = amplitudeToBinary(pattern_Standard);
    bitConf_Standard = symbolToBitConfidence(conf_Standard);
    [text_Standard, ~, BER_Standard, corr_Standard] = hammingSoftDecode(binary_Standard, bitConf_Standard, fileName);
    
    % Decode Weighted
    binary_Weighted = amplitudeToBinary(pattern_Weighted);
    bitConf_Weighted = symbolToBitConfidence(conf_Weighted);
    [text_Weighted, ~, BER_Weighted, corr_Weighted] = hammingSoftDecode(binary_Weighted, bitConf_Weighted, fileName);
    
    % Decode MultiScale
    binary_MultiScale = amplitudeToBinary(pattern_MultiScale);
    bitConf_MultiScale = symbolToBitConfidence(conf_MultiScale);
    [text_MultiScale, ~, BER_MultiScale, corr_MultiScale] = hammingSoftDecode(binary_MultiScale, bitConf_MultiScale, fileName);
    
    % Decode Phase
    binary_Phase = amplitudeToBinary(pattern_Phase);
    bitConf_Phase = symbolToBitConfidence(conf_Phase);
    [text_Phase, ~, BER_Phase, corr_Phase] = hammingSoftDecode(binary_Phase, bitConf_Phase, fileName);
    
    fprintf('\n--- Decoding Summary ---\n');
    fprintf('┌────────────┬──────────┬──────────┬────────────┬─────────────┐\n');
    fprintf('│ Method     │ Text     │ BER      │ Confidence │ Corrections │\n');
    fprintf('├────────────┼──────────┼──────────┼────────────┼─────────────┤\n');
    fprintf('│ Standard   │ %-8s │ %.6f │   %5.1f%%   │     %d       │\n', text_Standard, BER_Standard, mean(conf_Standard)*100, corr_Standard);
    fprintf('│ Weighted   │ %-8s │ %.6f │   %5.1f%%   │     %d       │\n', text_Weighted, BER_Weighted, mean(conf_Weighted)*100, corr_Weighted);
    fprintf('│ MultiScale │ %-8s │ %.6f │   %5.1f%%   │     %d       │\n', text_MultiScale, BER_MultiScale, mean(conf_MultiScale)*100, corr_MultiScale);
    fprintf('│ Phase      │ %-8s │ %.6f │   %5.1f%%   │     %d       │\n', text_Phase, BER_Phase, mean(conf_Phase)*100, corr_Phase);
    fprintf('└────────────┴──────────┴──────────┴────────────┴─────────────┘\n');
    
    %% ==================== SELECT BEST METHOD ====================
    % Score based on: BER (lower is better), Confidence (higher is better)
    scores = zeros(4, 1);
    methods = {'Standard', 'Weighted', 'MultiScale', 'Phase'};
    BERs = [BER_Standard, BER_Weighted, BER_MultiScale, BER_Phase];
    confs = [mean(conf_Standard), mean(conf_Weighted), mean(conf_MultiScale), mean(conf_Phase)];
    
    for i = 1:4
        % Score = Confidence - BER*100 (penalize errors heavily)
        scores(i) = confs(i) - BERs(i) * 100;
    end
    
    [bestScore, bestIdx] = max(scores);
    
    fprintf('\n');
    fprintf('╔════════════════════════════════════════════════════════════╗\n');
    fprintf('║  BEST METHOD: %-10s (Score: %.2f)                    ║\n', methods{bestIdx}, bestScore);
    fprintf('╚════════════════════════════════════════════════════════════╝\n');
    
    % Use best method's result
    switch bestIdx
        case 1
            amplitudePattern = pattern_Standard;
            decodedText = text_Standard;
            finalBER = BER_Standard;
            finalConf = mean(conf_Standard);
        case 2
            amplitudePattern = pattern_Weighted;
            decodedText = text_Weighted;
            finalBER = BER_Weighted;
            finalConf = mean(conf_Weighted);
        case 3
            amplitudePattern = pattern_MultiScale;
            decodedText = text_MultiScale;
            finalBER = BER_MultiScale;
            finalConf = mean(conf_MultiScale);
        case 4
            amplitudePattern = pattern_Phase;
            decodedText = text_Phase;
            finalBER = BER_Phase;
            finalConf = mean(conf_Phase);
    end
    
    fprintf('\n');
    fprintf('╔════════════════════════════════════════════════════════════╗\n');
    fprintf('║  FINAL DECODED TEXT: %-37s ║\n', decodedText);
    fprintf('║  BER: %.6f | Confidence: %.1f%%                        ║\n', finalBER, finalConf*100);
    fprintf('╚════════════════════════════════════════════════════════════╝\n');
    
    %% ==================== VISUALIZATION ====================
    plotMethodComparison(dataSegment, dataPositions, pulseTemplate, ...
        dataAmps_Standard, dataAmps_Weighted, dataAmps_MultiScale, dataAmps_Phase, ...
        refLevels_Standard, refLevels_Weighted, refLevels_MultiScale, refLevels_Phase, ...
        conf_Standard, conf_Weighted, conf_MultiScale, conf_Phase, ...
        pattern_Standard, pattern_Weighted, pattern_MultiScale, pattern_Phase, ...
        BER_Standard, BER_Weighted, BER_MultiScale, BER_Phase, ...
        weightedCorrSignal, multiScaleInfo, phaseInfo);
end

%% ==================== METHOD 0: STANDARD XCORR (BASELINE) ====================

function [pulsePositions, pulseAmps_Mean, pulseAmps_CorrNorm] = extractPulsesXCorr_Standard(signal, pulseTemplate, maxPulses)
    % STANDARD CROSS-CORRELATION
    % Baseline method - no special optimizations
    
    signal = signal(:);
    pulseTemplate = pulseTemplate(:);
    templateEnergy = sum(pulseTemplate.^2);
    
    % Standard cross-correlation
    correlationSignal = conv(signal, flipud(pulseTemplate), 'same');
    corrNormalized = correlationSignal / max(abs(correlationSignal));
    
    % Find peaks
    minPeakHeight = 0.2;
    minPeakDistance = round(length(pulseTemplate) * 0.7);
    [~, locs] = findpeaks(corrNormalized, 'MinPeakHeight', minPeakHeight, ...
        'MinPeakDistance', minPeakDistance);
    
    numPulses = min(length(locs), maxPulses);
    pulsePositions = locs(1:numPulses);
    halfWidth = round(length(pulseTemplate) / 2);
    
    pulseAmps_Mean = zeros(numPulses, 1);
    pulseAmps_CorrNorm = zeros(numPulses, 1);
    
    for i = 1:numPulses
        pos = pulsePositions(i);
        
        startIdx = max(1, pos - halfWidth);
        endIdx = min(length(signal), pos + halfWidth);
        pulseAmps_Mean(i) = mean(signal(startIdx:endIdx));
        
        % Parabolic interpolation
        if pos > 1 && pos < length(correlationSignal)
            y1 = correlationSignal(pos - 1);
            y2 = correlationSignal(pos);
            y3 = correlationSignal(pos + 1);
            denom = y1 - 2*y2 + y3;
            if abs(denom) > 1e-10
                delta = 0.5 * (y1 - y3) / denom;
                peakValue = y2 - 0.25 * (y1 - y3) * delta;
            else
                peakValue = y2;
            end
            pulseAmps_CorrNorm(i) = peakValue / templateEnergy;
        else
            pulseAmps_CorrNorm(i) = correlationSignal(pos) / templateEnergy;
        end
    end
end

%% ==================== METHOD 1: WEIGHTED CORRELATION ====================

function [pulsePositions, pulseAmps_Mean, pulseAmps_Weighted, weightedCorrSignal] = extractPulsesXCorr_Weighted(signal, pulseTemplate, maxPulses)
    % WEIGHTED CROSS-CORRELATION
    %
    % CONCEPT: Weight the center of the template more heavily than edges
    % WHY: Pulse center is most reliable, edges are affected by noise/overlap
    %
    % Weight options:
    % - Gaussian: exp(-x²/2σ²) - smooth, emphasizes center
    % - Triangular: 1 - |x|/max - linear decay from center
    % - Raised cosine: Same shape as pulse - matched to signal
    
    signal = signal(:);
    pulseTemplate = pulseTemplate(:);
    pulseWidth = length(pulseTemplate);
    
    % Create Gaussian weight window
    sigma = pulseWidth / 4;  % Standard deviation
    x = linspace(-pulseWidth/2, pulseWidth/2, pulseWidth);
    gaussianWeight = exp(-x.^2 / (2 * sigma^2));
    gaussianWeight = gaussianWeight(:);
    
    % Apply weight to template
    weightedTemplate = pulseTemplate .* gaussianWeight;
    
    % Normalize weighted template energy
    weightedEnergy = sum(weightedTemplate.^2);
    
    % Weighted cross-correlation
    weightedCorrSignal = conv(signal, flipud(weightedTemplate), 'same');
    corrNormalized = weightedCorrSignal / max(abs(weightedCorrSignal));
    
    % Find peaks
    minPeakHeight = 0.2;
    minPeakDistance = round(pulseWidth * 0.7);
    [~, locs] = findpeaks(corrNormalized, 'MinPeakHeight', minPeakHeight, ...
        'MinPeakDistance', minPeakDistance);
    
    numPulses = min(length(locs), maxPulses);
    pulsePositions = locs(1:numPulses);
    halfWidth = round(pulseWidth / 2);
    
    pulseAmps_Mean = zeros(numPulses, 1);
    pulseAmps_Weighted = zeros(numPulses, 1);
    
    for i = 1:numPulses
        pos = pulsePositions(i);
        
        startIdx = max(1, pos - halfWidth);
        endIdx = min(length(signal), pos + halfWidth);
        pulseAmps_Mean(i) = mean(signal(startIdx:endIdx));
        
        % Parabolic interpolation on weighted correlation
        if pos > 1 && pos < length(weightedCorrSignal)
            y1 = weightedCorrSignal(pos - 1);
            y2 = weightedCorrSignal(pos);
            y3 = weightedCorrSignal(pos + 1);
            denom = y1 - 2*y2 + y3;
            if abs(denom) > 1e-10
                delta = 0.5 * (y1 - y3) / denom;
                peakValue = y2 - 0.25 * (y1 - y3) * delta;
            else
                peakValue = y2;
            end
            pulseAmps_Weighted(i) = peakValue / weightedEnergy;
        else
            pulseAmps_Weighted(i) = weightedCorrSignal(pos) / weightedEnergy;
        end
    end
end

%% ==================== METHOD 2: MULTI-SCALE MATCHED FILTER ====================

function [pulsePositions, pulseAmps_Mean, pulseAmps_MultiScale, multiScaleInfo] = extractPulsesXCorr_MultiScale(signal, pulseTemplate, maxPulses)
    % MULTI-SCALE MATCHED FILTER
    %
    % CONCEPT: Use multiple template widths to handle pulse width variation
    % WHY: Real pulses may vary in width due to channel effects
    %
    % Process:
    % 1. Create templates at multiple scales (80%, 100%, 120%)
    % 2. Correlate signal with each template
    % 3. For each pulse, use the scale with highest correlation
    
    signal = signal(:);
    pulseTemplate = pulseTemplate(:);
    pulseWidth = length(pulseTemplate);
    
    % Define scales
    scales = [0.8, 1.0, 1.2];
    numScales = length(scales);
    
    % Create scaled templates
    scaledTemplates = cell(numScales, 1);
    scaledEnergies = zeros(numScales, 1);
    corrSignals = cell(numScales, 1);
    
    for s = 1:numScales
        scaledWidth = round(pulseWidth * scales(s));
        scaledTemplates{s} = createPulseTemplate(scaledWidth);
        scaledEnergies(s) = sum(scaledTemplates{s}.^2);
        
        % Correlation with each scale
        corrSignals{s} = conv(signal, flipud(scaledTemplates{s}(:)), 'same');
    end
    
    % Combine correlations: take max across scales at each point
    combinedCorr = zeros(length(signal), 1);
    bestScale = zeros(length(signal), 1);
    
    for i = 1:length(signal)
        corrValues = zeros(numScales, 1);
        for s = 1:numScales
            corrValues(s) = corrSignals{s}(i);
        end
        [combinedCorr(i), bestScale(i)] = max(corrValues);
    end
    
    % Normalize for peak finding
    corrNormalized = combinedCorr / max(abs(combinedCorr));
    
    % Find peaks
    minPeakHeight = 0.2;
    minPeakDistance = round(pulseWidth * 0.7);
    [~, locs] = findpeaks(corrNormalized, 'MinPeakHeight', minPeakHeight, ...
        'MinPeakDistance', minPeakDistance);
    
    numPulses = min(length(locs), maxPulses);
    pulsePositions = locs(1:numPulses);
    halfWidth = round(pulseWidth / 2);
    
    pulseAmps_Mean = zeros(numPulses, 1);
    pulseAmps_MultiScale = zeros(numPulses, 1);
    selectedScales = zeros(numPulses, 1);
    
    for i = 1:numPulses
        pos = pulsePositions(i);
        
        startIdx = max(1, pos - halfWidth);
        endIdx = min(length(signal), pos + halfWidth);
        pulseAmps_Mean(i) = mean(signal(startIdx:endIdx));
        
        % Find best scale for this pulse
        scaleIdx = bestScale(pos);
        selectedScales(i) = scales(scaleIdx);
        
        % Use correlation from best scale
        corrSignal = corrSignals{scaleIdx};
        energy = scaledEnergies(scaleIdx);
        
        % Parabolic interpolation
        if pos > 1 && pos < length(corrSignal)
            y1 = corrSignal(pos - 1);
            y2 = corrSignal(pos);
            y3 = corrSignal(pos + 1);
            denom = y1 - 2*y2 + y3;
            if abs(denom) > 1e-10
                delta = 0.5 * (y1 - y3) / denom;
                peakValue = y2 - 0.25 * (y1 - y3) * delta;
            else
                peakValue = y2;
            end
            pulseAmps_MultiScale(i) = peakValue / energy;
        else
            pulseAmps_MultiScale(i) = corrSignal(pos) / energy;
        end
    end
    
    % Store info for visualization
    multiScaleInfo.scales = scales;
    multiScaleInfo.corrSignals = corrSignals;
    multiScaleInfo.combinedCorr = combinedCorr;
    multiScaleInfo.selectedScales = selectedScales;
    
    fprintf('  Selected scales per pulse: '); fprintf('%.1f ', selectedScales); fprintf('\n');
end

%% ==================== METHOD 3: PHASE-AWARE CORRELATION ====================

function [pulsePositions, pulseAmps_Mean, pulseAmps_Phase, phaseInfo] = extractPulsesXCorr_PhaseAware(signal, pulseTemplate, maxPulses)
    % PHASE-AWARE CROSS-CORRELATION
    %
    % CONCEPT: Use complex (analytic) signal to get both magnitude and phase
    % WHY: Phase information can help identify distorted or shifted pulses
    %
    % Process:
    % 1. Convert signal to analytic signal using Hilbert transform
    % 2. Convert template to analytic form
    % 3. Complex correlation gives magnitude AND phase
    % 4. Use magnitude for amplitude, phase for quality assessment
    
    signal = signal(:);
    pulseTemplate = pulseTemplate(:);
    pulseWidth = length(pulseTemplate);
    
    % Create analytic signals using Hilbert transform
    analyticSignal = hilbert(signal);
    analyticTemplate = hilbert(pulseTemplate);
    
    templateEnergy = sum(abs(analyticTemplate).^2);
    
    % Complex correlation
    complexCorr = conv(analyticSignal, flipud(conj(analyticTemplate)), 'same');
    
    % Extract magnitude and phase
    magnitudeCorr = abs(complexCorr);
    phaseCorr = angle(complexCorr);
    
    % Normalize for peak finding
    corrNormalized = magnitudeCorr / max(magnitudeCorr);
    
    % Find peaks
    minPeakHeight = 0.2;
    minPeakDistance = round(pulseWidth * 0.7);
    [~, locs] = findpeaks(corrNormalized, 'MinPeakHeight', minPeakHeight, ...
        'MinPeakDistance', minPeakDistance);
    
    numPulses = min(length(locs), maxPulses);
    pulsePositions = locs(1:numPulses);
    halfWidth = round(pulseWidth / 2);
    
    pulseAmps_Mean = zeros(numPulses, 1);
    pulseAmps_Phase = zeros(numPulses, 1);
    pulsePhases = zeros(numPulses, 1);
    
    for i = 1:numPulses
        pos = pulsePositions(i);
        
        startIdx = max(1, pos - halfWidth);
        endIdx = min(length(signal), pos + halfWidth);
        pulseAmps_Mean(i) = mean(signal(startIdx:endIdx));
        
        % Get phase at peak
        pulsePhases(i) = phaseCorr(pos);
        
        % Parabolic interpolation on magnitude
        if pos > 1 && pos < length(magnitudeCorr)
            y1 = magnitudeCorr(pos - 1);
            y2 = magnitudeCorr(pos);
            y3 = magnitudeCorr(pos + 1);
            denom = y1 - 2*y2 + y3;
            if abs(denom) > 1e-10
                delta = 0.5 * (y1 - y3) / denom;
                peakValue = y2 - 0.25 * (y1 - y3) * delta;
            else
                peakValue = y2;
            end
            pulseAmps_Phase(i) = peakValue / templateEnergy;
        else
            pulseAmps_Phase(i) = magnitudeCorr(pos) / templateEnergy;
        end
    end
    
    % Store info for visualization
    phaseInfo.magnitudeCorr = magnitudeCorr;
    phaseInfo.phaseCorr = phaseCorr;
    phaseInfo.pulsePhases = pulsePhases;
    phaseInfo.complexCorr = complexCorr;
    
    fprintf('  Pulse phases (rad): '); fprintf('%.2f ', pulsePhases); fprintf('\n');
end

%% ==================== DYNAMIC THRESHOLDING ====================

function [pattern, confidence] = classifyDynamicThreshold(amplitudes, referenceLevels)
    symbolValues = [150, 120, 90, 60];
    
    amplitudes = amplitudes(:);
    referenceLevels = referenceLevels(:)';
    
    numPulses = length(amplitudes);
    pattern = zeros(numPulses, 1);
    confidence = zeros(numPulses, 1);
    
    for i = 1:numPulses
        distances = abs(amplitudes(i) - referenceLevels);
        [~, closestIdx] = min(distances);
        pattern(i) = symbolValues(closestIdx);
        
        sortedDist = sort(distances);
        d1 = sortedDist(1);
        d2 = sortedDist(2);
        
        if d1 + d2 > 0
            confidence(i) = 1 - (d1 / (d1 + d2));
        else
            confidence(i) = 1;
        end
    end
end

function pattern = classifyFixedThreshold(amplitudes, thresholds)
    amplitudes = amplitudes(:);
    pattern = zeros(length(amplitudes), 1);
    
    for i = 1:length(amplitudes)
        if amplitudes(i) >= thresholds(1)
            pattern(i) = 150;
        elseif amplitudes(i) >= thresholds(2)
            pattern(i) = 120;
        elseif amplitudes(i) >= thresholds(3)
            pattern(i) = 90;
        else
            pattern(i) = 60;
        end
    end
end

%% ==================== SOFT-DECISION HAMMING ====================

function [decodedText, decodedBits, BER, numCorrections] = hammingSoftDecode(encodedBinary, bitConfidences, fileName)
    if mod(length(encodedBinary), 7) ~= 0
        error('Binary length must be multiple of 7');
    end
    
    H = [1 0 1 0 1 0 1; 0 1 1 0 0 1 1; 0 0 0 1 1 1 1];
    decodedBits = [];
    numCorrections = 0;
    
    numCodewords = length(encodedBinary) / 7;
    
    for i = 1:numCodewords
        startIdx = (i-1)*7 + 1;
        endIdx = i*7;
        
        codeword = encodedBinary(startIdx:endIdx) - '0';
        codeConfidence = bitConfidences(startIdx:endIdx);
        
        syndrome = mod(codeword * H', 2);
        errIdx = binaryToDecimal(flip(syndrome));
        
        if errIdx > 0
            numCorrections = numCorrections + 1;
            codeword(errIdx) = mod(codeword(errIdx) + 1, 2);
        end
        
        decodedBits = [decodedBits, codeword(3), codeword(5), codeword(6), codeword(7)];
    end
    
    [~, name, ~] = fileparts(fileName);
    refBinary = '';
    for i = 1:length(name)
        refBinary = [refBinary, dec2bin(double(name(i)), 8)];
    end
    
    decodedStr = sprintf('%d', decodedBits);
    minLen = min(length(refBinary), length(decodedStr));
    BER = sum((decodedStr(1:minLen) - '0') ~= (refBinary(1:minLen) - '0')) / minLen;
    
    decodedText = '';
    for i = 1:floor(length(decodedBits)/8)
        byte = decodedBits((i-1)*8+1 : i*8);
        decodedText = [decodedText, char(binaryToDecimal(byte))];
    end
end

function bitConfidences = symbolToBitConfidence(symbolConfidences)
    numSymbols = length(symbolConfidences);
    bitConfidences = zeros(1, numSymbols * 2);
    for i = 1:numSymbols
        bitConfidences(2*i - 1) = symbolConfidences(i);
        bitConfidences(2*i) = symbolConfidences(i);
    end
end

%% ==================== VISUALIZATION ====================

function plotMethodComparison(dataSegment, dataPositions, pulseTemplate, ...
        amps_Standard, amps_Weighted, amps_MultiScale, amps_Phase, ...
        ref_Standard, ref_Weighted, ref_MultiScale, ref_Phase, ...
        conf_Standard, conf_Weighted, conf_MultiScale, conf_Phase, ...
        pat_Standard, pat_Weighted, pat_MultiScale, pat_Phase, ...
        BER_Standard, BER_Weighted, BER_MultiScale, BER_Phase, ...
        weightedCorrSignal, multiScaleInfo, phaseInfo)
    
    figure('Name', 'XCorr Optimization Comparison', 'Position', [20 20 1800 950]);
    
    % Colors for methods
    colors = struct('Standard', [0.2 0.4 0.8], 'Weighted', [0.8 0.4 0.2], ...
                   'MultiScale', [0.2 0.7 0.3], 'Phase', [0.7 0.2 0.7]);
    
    % Row 1: Correlation Signals
    subplot(3,4,1);
    stdCorr = conv(dataSegment(:), flipud(pulseTemplate(:)), 'same');
    plot(stdCorr, 'Color', colors.Standard, 'LineWidth', 1.5);
    hold on;
    validPos = dataPositions(dataPositions <= length(stdCorr));
    plot(validPos, stdCorr(validPos), 'ko', 'MarkerSize', 8, 'LineWidth', 2);
    xlabel('Sample'); ylabel('Correlation');
    title('Standard XCorr');
    grid on;
    
    subplot(3,4,2);
    plot(weightedCorrSignal, 'Color', colors.Weighted, 'LineWidth', 1.5);
    hold on;
    plot(validPos, weightedCorrSignal(validPos), 'ko', 'MarkerSize', 8, 'LineWidth', 2);
    xlabel('Sample'); ylabel('Correlation');
    title('Weighted XCorr');
    grid on;
    
    subplot(3,4,3);
    plot(multiScaleInfo.combinedCorr, 'Color', colors.MultiScale, 'LineWidth', 1.5);
    hold on;
    plot(validPos, multiScaleInfo.combinedCorr(validPos), 'ko', 'MarkerSize', 8, 'LineWidth', 2);
    xlabel('Sample'); ylabel('Correlation');
    title('Multi-Scale XCorr (Combined)');
    grid on;
    
    subplot(3,4,4);
    plot(phaseInfo.magnitudeCorr, 'Color', colors.Phase, 'LineWidth', 1.5);
    hold on;
    plot(validPos, phaseInfo.magnitudeCorr(validPos), 'ko', 'MarkerSize', 8, 'LineWidth', 2);
    xlabel('Sample'); ylabel('Magnitude');
    title('Phase-Aware (Magnitude)');
    grid on;
    
    % Row 2: Amplitude Extraction
    subplot(3,4,5);
    bar(amps_Standard, 'FaceColor', colors.Standard);
    hold on;
    for j = 1:4
        yline(ref_Standard(j), '--', 'LineWidth', 1.5);
    end
    xlabel('Pulse'); ylabel('Amplitude');
    title('Standard Amplitudes');
    grid on;
    
    subplot(3,4,6);
    bar(amps_Weighted, 'FaceColor', colors.Weighted);
    hold on;
    for j = 1:4
        yline(ref_Weighted(j), '--', 'LineWidth', 1.5);
    end
    xlabel('Pulse'); ylabel('Amplitude');
    title('Weighted Amplitudes');
    grid on;
    
    subplot(3,4,7);
    bar(amps_MultiScale, 'FaceColor', colors.MultiScale);
    hold on;
    for j = 1:4
        yline(ref_MultiScale(j), '--', 'LineWidth', 1.5);
    end
    xlabel('Pulse'); ylabel('Amplitude');
    title('MultiScale Amplitudes');
    grid on;
    
    subplot(3,4,8);
    bar(amps_Phase, 'FaceColor', colors.Phase);
    hold on;
    for j = 1:4
        yline(ref_Phase(j), '--', 'LineWidth', 1.5);
    end
    xlabel('Pulse'); ylabel('Amplitude');
    title('Phase-Aware Amplitudes');
    grid on;
    
    % Row 3: Confidence Comparison and Summary
    subplot(3,4,9);
    x = 1:length(conf_Standard);
    width = 0.2;
    bar(x - 1.5*width, conf_Standard*100, width, 'FaceColor', colors.Standard);
    hold on;
    bar(x - 0.5*width, conf_Weighted*100, width, 'FaceColor', colors.Weighted);
    bar(x + 0.5*width, conf_MultiScale*100, width, 'FaceColor', colors.MultiScale);
    bar(x + 1.5*width, conf_Phase*100, width, 'FaceColor', colors.Phase);
    yline(60, 'r--', 'LineWidth', 2);
    xlabel('Pulse'); ylabel('Confidence (%)');
    title('Confidence Comparison');
    legend('Standard', 'Weighted', 'MultiScale', 'Phase', 'Low Threshold', 'Location', 'best');
    ylim([0 100]);
    grid on;
    
    subplot(3,4,10);
    avgConfs = [mean(conf_Standard), mean(conf_Weighted), mean(conf_MultiScale), mean(conf_Phase)] * 100;
    b = bar(avgConfs);
    b.FaceColor = 'flat';
    b.CData = [colors.Standard; colors.Weighted; colors.MultiScale; colors.Phase];
    xticklabels({'Standard', 'Weighted', 'MultiScale', 'Phase'});
    ylabel('Average Confidence (%)');
    title('Average Confidence by Method');
    ylim([0 100]);
    grid on;
    
    subplot(3,4,11);
    BERs = [BER_Standard, BER_Weighted, BER_MultiScale, BER_Phase] * 100;
    b = bar(BERs);
    b.FaceColor = 'flat';
    b.CData = [colors.Standard; colors.Weighted; colors.MultiScale; colors.Phase];
    xticklabels({'Standard', 'Weighted', 'MultiScale', 'Phase'});
    ylabel('BER (%)');
    title('Bit Error Rate by Method');
    grid on;
    
    % Summary Panel
    subplot(3,4,12);
    axis off;
    
    text(0.05, 0.95, 'METHOD COMPARISON SUMMARY', 'FontSize', 12, 'FontWeight', 'bold');
    
    methods = {'Standard', 'Weighted', 'MultiScale', 'Phase'};
    confs = [mean(conf_Standard), mean(conf_Weighted), mean(conf_MultiScale), mean(conf_Phase)];
    BERs = [BER_Standard, BER_Weighted, BER_MultiScale, BER_Phase];
    
    [~, bestConfIdx] = max(confs);
    [~, bestBERIdx] = min(BERs);
    
    y = 0.80;
    for i = 1:4
        if i == bestConfIdx && i == bestBERIdx
            marker = '★ BEST';
            fontWeight = 'bold';
        elseif i == bestConfIdx
            marker = '↑ Best Conf';
            fontWeight = 'normal';
        elseif i == bestBERIdx
            marker = '↓ Best BER';
            fontWeight = 'normal';
        else
            marker = '';
            fontWeight = 'normal';
        end
        
        text(0.05, y, sprintf('%s: %.1f%% conf, %.4f BER %s', ...
            methods{i}, confs(i)*100, BERs(i), marker), ...
            'FontSize', 10, 'FontWeight', fontWeight);
        y = y - 0.12;
    end
       
    sgtitle('Cross-Correlation Optimization Methods Comparison', 'FontSize', 14, 'FontWeight', 'bold');
end

%% ==================== HELPER FUNCTIONS ====================

function template = createPulseTemplate(pulseWidth)
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

%% ==================== HYBRID PREAMBLE DETECTION ====================

function [preambleEndIndex, searchRegion] = findPreambleHybrid(signal)
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
    t = linspace(0, pi, pulseWidth);
    singlePulse = (1 - cos(t)) / 2;
    gap = zeros(1, round(pulseWidth * 0.5));
    template = [];
    for i = 1:4
        template = [template, singlePulse, gap];
    end
    template = template / max(template);
end

%% ==================== CONVERSION FUNCTIONS ====================

function binaryString = amplitudeToBinary(amplitudeArray)
    binaryString = '';
    for i = 1:length(amplitudeArray)
        switch amplitudeArray(i)
            case 150, binaryString = [binaryString, '10'];
            case 120, binaryString = [binaryString, '11'];
            case 90,  binaryString = [binaryString, '01'];
            case 60,  binaryString = [binaryString, '00'];
        end
    end
end

function decVal = binaryToDecimal(binArray)
    decVal = sum(binArray .* 2.^(length(binArray)-1:-1:0));
end