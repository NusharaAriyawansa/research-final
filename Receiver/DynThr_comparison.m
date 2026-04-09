function amplitudePattern = DynThr_comparison(normalizedAmplitude, fileName)
    % PWAM RECEIVER - Dynamic Thresholding Methods Comparison
    %
    % COMPARING 3 DYNAMIC THRESHOLDING METHODS:
    % 1. Reference Interpolation - Interpolates between reference levels
    % 2. Confidence-Weighted Update - Updates references based on confidence
    % 3. Second-Order Confidence - Uses rate of change of distances
    %
    % All methods use Weighted Correlation for amplitude extraction
    
    fprintf('\n');
    fprintf('╔════════════════════════════════════════════════════════════╗\n');
    fprintf('║  PWAM RECEIVER - Dynamic Thresholding Comparison           ║\n');
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
    
    % Extract 4 calibration pulses using Weighted Correlation
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
    
    % Reference levels for Dynamic Thresholding
    referenceLevels = calibAmps_CorrNorm_Sorted;
    
    fprintf('✓ Fixed Thresholds:         [%.4f, %.4f, %.4f, %.4f]\n', thresholds);
    fprintf('✓ Dynamic Reference Levels: [%.4f, %.4f, %.4f, %.4f]\n', referenceLevels);
    
    calibrationEndIndex = preambleEndIndex + calibPositions(4) + round(pulseWidth/2);
    fprintf('Calibration end index: %d\n', calibrationEndIndex);
    
    %% ==================== STEP 3: DATA LENGTH ====================
    fprintf('\n=== Step 3: Data Length ===\n');
    
    lenSegment = normalizedAmplitude(calibrationEndIndex+1:end);
    
    % Extract 4 length pulses
    [lenPositions, ~, lenAmps_CorrNorm] = extractPulsesXCorr(lenSegment, pulseTemplate, 4);
    
    fprintf('Length pulse positions: [%d, %d, %d, %d]\n', lenPositions);
    fprintf('Length amps (CorrNorm): [%.4f, %.4f, %.4f, %.4f]\n', lenAmps_CorrNorm);
    
    % Use basic dynamic thresholding for length (consistent)
    [lenPattern, ~] = classifyDynamicThreshold_Basic(lenAmps_CorrNorm, referenceLevels);
    
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
    
    %% ==================== STEP 4: DATA EXTRACTION ====================
    fprintf('\n=== Step 4: Data Extraction ===\n');
    
    dataSegment = normalizedAmplitude(lenEndIndex:end);
    numDataPulses = floor(dataLength / 2);
    
    % Extract data pulses using Weighted Correlation
    [dataPositions, dataAmps_Mean, dataAmps_CorrNorm] = ...
        extractPulsesXCorr(dataSegment, pulseTemplate, numDataPulses);
    
    fprintf('Extracted %d data pulses\n', length(dataAmps_Mean));
    fprintf('Data pulse positions: '); fprintf('%d ', dataPositions); fprintf('\n');
    fprintf('Data amps (CorrNorm): '); fprintf('%.4f ', dataAmps_CorrNorm); fprintf('\n');
    
    %% ==================== STEP 5: CLASSIFICATION WITH ALL 3 METHODS ====================
    fprintf('\n');
    fprintf('╔════════════════════════════════════════════════════════════╗\n');
    fprintf('║         DYNAMIC THRESHOLDING METHODS COMPARISON            ║\n');
    fprintf('╚════════════════════════════════════════════════════════════╝\n');
    
    % Fixed threshold (baseline)
    pattern_Fixed = classifyFixedThreshold(dataAmps_Mean, thresholds);
    
    % Method 0: Basic Dynamic Thresholding (original)
    fprintf('\n--- Method 0: BASIC Dynamic Thresholding (Original) ---\n');
    [pattern_Basic, conf_Basic] = classifyDynamicThreshold_Basic(dataAmps_CorrNorm, referenceLevels);
    fprintf('Basic pattern:     '); fprintf('%d ', pattern_Basic); fprintf('\n');
    fprintf('Basic confidence:  '); fprintf('%.0f%% ', conf_Basic*100); fprintf('\n');
    fprintf('Avg confidence: %.2f%%\n', mean(conf_Basic)*100);
    
    % Method 1: Reference Interpolation
    fprintf('\n--- Method 1: REFERENCE INTERPOLATION ---\n');
    [pattern_Interp, conf_Interp, interpInfo] = classifyDynamicThreshold_Interpolation(dataAmps_CorrNorm, referenceLevels);
    fprintf('Interp pattern:    '); fprintf('%d ', pattern_Interp); fprintf('\n');
    fprintf('Interp confidence: '); fprintf('%.0f%% ', conf_Interp*100); fprintf('\n');
    fprintf('Avg confidence: %.2f%%\n', mean(conf_Interp)*100);
    
    % Method 2: Confidence-Weighted Update
    fprintf('\n--- Method 2: CONFIDENCE-WEIGHTED UPDATE ---\n');
    [pattern_ConfWeight, conf_ConfWeight, confWeightInfo] = classifyDynamicThreshold_ConfidenceWeighted(dataAmps_CorrNorm, referenceLevels);
    fprintf('ConfWeight pattern:    '); fprintf('%d ', pattern_ConfWeight); fprintf('\n');
    fprintf('ConfWeight confidence: '); fprintf('%.0f%% ', conf_ConfWeight*100); fprintf('\n');
    fprintf('Avg confidence: %.2f%%\n', mean(conf_ConfWeight)*100);
    
    % Method 3: Second-Order Confidence
    fprintf('\n--- Method 3: SECOND-ORDER CONFIDENCE ---\n');
    [pattern_SecondOrder, conf_SecondOrder, secondOrderInfo] = classifyDynamicThreshold_SecondOrder(dataAmps_CorrNorm, referenceLevels);
    fprintf('SecondOrder pattern:    '); fprintf('%d ', pattern_SecondOrder); fprintf('\n');
    fprintf('SecondOrder confidence: '); fprintf('%.0f%% ', conf_SecondOrder*100); fprintf('\n');
    fprintf('Avg confidence: %.2f%%\n', mean(conf_SecondOrder)*100);
    
    %% ==================== PATTERN COMPARISON TABLE ====================
    fprintf('\n');
    fprintf('╔════════════════════════════════════════════════════════════╗\n');
    fprintf('║              PATTERN COMPARISON TABLE                      ║\n');
    fprintf('╚════════════════════════════════════════════════════════════╝\n');
    
    fprintf('\nPulse | Fixed | Basic | Interp | ConfWt | SecOrd | Agreement\n');
    fprintf('------+-------+-------+--------+--------+--------+-----------\n');
    for i = 1:length(pattern_Fixed)
        patterns = [pattern_Basic(i), pattern_Interp(i), pattern_ConfWeight(i), pattern_SecondOrder(i)];
        if all(patterns == patterns(1))
            agreeStr = '✓ ALL';
        elseif sum(patterns == mode(patterns)) >= 3
            agreeStr = sprintf('~%d agree', sum(patterns == mode(patterns)));
        else
            agreeStr = '✗ SPLIT';
        end
        fprintf('  %2d  |  %3d  |  %3d  |  %3d   |  %3d   |  %3d   | %s\n', ...
            i, pattern_Fixed(i), pattern_Basic(i), pattern_Interp(i), ...
            pattern_ConfWeight(i), pattern_SecondOrder(i), agreeStr);
    end
    
    %% ==================== CONFIDENCE COMPARISON TABLE ====================
    fprintf('\n');
    fprintf('╔════════════════════════════════════════════════════════════╗\n');
    fprintf('║             CONFIDENCE COMPARISON TABLE                    ║\n');
    fprintf('╚════════════════════════════════════════════════════════════╝\n');
    
    fprintf('\nPulse | Basic  | Interp | ConfWt | SecOrd | Best Method\n');
    fprintf('------+--------+--------+--------+--------+-------------\n');
    for i = 1:length(conf_Basic)
        confs = [conf_Basic(i), conf_Interp(i), conf_ConfWeight(i), conf_SecondOrder(i)];
        [~, bestIdx] = max(confs);
        methodNames = {'Basic', 'Interp', 'ConfWt', 'SecOrd'};
        fprintf('  %2d  | %5.1f%% | %5.1f%% | %5.1f%% | %5.1f%% | %s\n', ...
            i, conf_Basic(i)*100, conf_Interp(i)*100, ...
            conf_ConfWeight(i)*100, conf_SecondOrder(i)*100, methodNames{bestIdx});
    end
    
    %% ==================== DECODE WITH ALL METHODS ====================
    fprintf('\n');
    fprintf('╔════════════════════════════════════════════════════════════╗\n');
    fprintf('║                    DECODING RESULTS                        ║\n');
    fprintf('╚════════════════════════════════════════════════════════════╝\n');
    
    % Decode Basic
    binary_Basic = amplitudeToBinary(pattern_Basic);
    bitConf_Basic = symbolToBitConfidence(conf_Basic);
    [text_Basic, ~, BER_Basic, corr_Basic] = hammingSoftDecode(binary_Basic, bitConf_Basic, fileName);
    
    % Decode Interpolation
    binary_Interp = amplitudeToBinary(pattern_Interp);
    bitConf_Interp = symbolToBitConfidence(conf_Interp);
    [text_Interp, ~, BER_Interp, corr_Interp] = hammingSoftDecode(binary_Interp, bitConf_Interp, fileName);
    
    % Decode Confidence-Weighted
    binary_ConfWeight = amplitudeToBinary(pattern_ConfWeight);
    bitConf_ConfWeight = symbolToBitConfidence(conf_ConfWeight);
    [text_ConfWeight, ~, BER_ConfWeight, corr_ConfWeight] = hammingSoftDecode(binary_ConfWeight, bitConf_ConfWeight, fileName);
    
    % Decode Second-Order
    binary_SecondOrder = amplitudeToBinary(pattern_SecondOrder);
    bitConf_SecondOrder = symbolToBitConfidence(conf_SecondOrder);
    [text_SecondOrder, ~, BER_SecondOrder, corr_SecondOrder] = hammingSoftDecode(binary_SecondOrder, bitConf_SecondOrder, fileName);
    
    fprintf('\n');
    fprintf('┌──────────────────┬──────────┬──────────┬────────────┬─────────────┐\n');
    fprintf('│ Method           │ Text     │ BER      │ Avg Conf   │ Corrections │\n');
    fprintf('├──────────────────┼──────────┼──────────┼────────────┼─────────────┤\n');
    fprintf('│ Basic            │ %-8s │ %.6f │   %5.1f%%   │     %d       │\n', text_Basic, BER_Basic, mean(conf_Basic)*100, corr_Basic);
    fprintf('│ Ref Interpolation│ %-8s │ %.6f │   %5.1f%%   │     %d       │\n', text_Interp, BER_Interp, mean(conf_Interp)*100, corr_Interp);
    fprintf('│ Conf-Weighted    │ %-8s │ %.6f │   %5.1f%%   │     %d       │\n', text_ConfWeight, BER_ConfWeight, mean(conf_ConfWeight)*100, corr_ConfWeight);
    fprintf('│ Second-Order     │ %-8s │ %.6f │   %5.1f%%   │     %d       │\n', text_SecondOrder, BER_SecondOrder, mean(conf_SecondOrder)*100, corr_SecondOrder);
    fprintf('└──────────────────┴──────────┴──────────┴────────────┴─────────────┘\n');
    
    %% ==================== SELECT BEST METHOD ====================
    methods = {'Basic', 'Ref Interpolation', 'Conf-Weighted', 'Second-Order'};
    BERs = [BER_Basic, BER_Interp, BER_ConfWeight, BER_SecondOrder];
    confs = [mean(conf_Basic), mean(conf_Interp), mean(conf_ConfWeight), mean(conf_SecondOrder)];
    patterns = {pattern_Basic, pattern_Interp, pattern_ConfWeight, pattern_SecondOrder};
    texts = {text_Basic, text_Interp, text_ConfWeight, text_SecondOrder};
    
    % Score: prioritize BER (lower is better), then confidence (higher is better)
    scores = confs - BERs * 100;
    [bestScore, bestIdx] = max(scores);
    
    fprintf('\n');
    fprintf('╔════════════════════════════════════════════════════════════╗\n');
    fprintf('║  BEST METHOD: %-15s (Score: %.2f)              ║\n', methods{bestIdx}, bestScore);
    fprintf('║  DECODED TEXT: %-43s ║\n', texts{bestIdx});
    fprintf('║  BER: %.6f | Confidence: %.1f%%                        ║\n', BERs(bestIdx), confs(bestIdx)*100);
    fprintf('╚════════════════════════════════════════════════════════════╝\n');
    
    amplitudePattern = patterns{bestIdx};
    
    %% ==================== VISUALIZATION ====================
    plotMethodComparison(dataSegment, dataPositions, dataAmps_CorrNorm, referenceLevels, ...
        pattern_Basic, pattern_Interp, pattern_ConfWeight, pattern_SecondOrder, ...
        conf_Basic, conf_Interp, conf_ConfWeight, conf_SecondOrder, ...
        BER_Basic, BER_Interp, BER_ConfWeight, BER_SecondOrder, ...
        interpInfo, confWeightInfo, secondOrderInfo, pulseTemplate);
end

%% ==================== METHOD 0: BASIC DYNAMIC THRESHOLDING ====================

function [pattern, confidence] = classifyDynamicThreshold_Basic(amplitudes, referenceLevels)
    % BASIC DYNAMIC THRESHOLDING (Original Method)
    %
    % Simple distance-based classification:
    % 1. Calculate distance to each reference level
    % 2. Choose closest reference
    % 3. Confidence = 1 - d1/(d1+d2)
    
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

%% ==================== METHOD 1: REFERENCE INTERPOLATION ====================

function [pattern, confidence, info] = classifyDynamicThreshold_Interpolation(amplitudes, referenceLevels)
    % REFERENCE INTERPOLATION
    %
    % Instead of just picking closest reference, this method:
    % 1. Finds the two closest reference levels
    % 2. Calculates where the amplitude falls BETWEEN them
    % 3. Uses interpolation position for more nuanced confidence
    %
    % Key insight: An amplitude exactly between two levels is ambiguous,
    % while one close to a reference is confident.
    %
    % Interpolation factor: t = (amp - ref_lower) / (ref_upper - ref_lower)
    % - t ≈ 0: closer to lower reference
    % - t ≈ 1: closer to upper reference
    % - t ≈ 0.5: ambiguous (low confidence)
    %
    % Confidence = 1 - 2*|t - round(t)|  (peaks at t=0 or t=1)
    
    symbolValues = [150, 120, 90, 60];
    
    amplitudes = amplitudes(:);
    refLevels = sort(referenceLevels(:), 'descend')';  % Ensure descending order
    
    numPulses = length(amplitudes);
    pattern = zeros(numPulses, 1);
    confidence = zeros(numPulses, 1);
    interpFactors = zeros(numPulses, 1);
    bracketIndices = zeros(numPulses, 2);
    
    for i = 1:numPulses
        amp = amplitudes(i);
        
        % Find which two reference levels bracket this amplitude
        if amp >= refLevels(1)
            % Above highest reference
            closestIdx = 1;
            t = 0;  % Treat as at the reference
            bracketIndices(i,:) = [1, 1];
        elseif amp <= refLevels(4)
            % Below lowest reference
            closestIdx = 4;
            t = 0;
            bracketIndices(i,:) = [4, 4];
        else
            % Between two references - find the bracket
            for j = 1:3
                if amp <= refLevels(j) && amp >= refLevels(j+1)
                    upperRef = refLevels(j);
                    lowerRef = refLevels(j+1);
                    
                    % Interpolation factor
                    t = (amp - lowerRef) / (upperRef - lowerRef);
                    
                    % Decide which reference is closer
                    if t >= 0.5
                        closestIdx = j;      % Closer to upper
                    else
                        closestIdx = j + 1;  % Closer to lower
                    end
                    
                    bracketIndices(i,:) = [j, j+1];
                    break;
                end
            end
        end
        
        pattern(i) = symbolValues(closestIdx);
        interpFactors(i) = t;
        
        % Confidence based on interpolation position
        % Maximum confidence when t=0 or t=1 (exactly at reference)
        % Minimum confidence when t=0.5 (exactly between references)
        distFromNearest = abs(t - round(t));  % 0 to 0.5
        confidence(i) = 1 - 2 * distFromNearest;  % 1 to 0
        
        % Boost confidence if amplitude is very close to a reference
        distances = abs(amp - refLevels);
        minDist = min(distances);
        refSpacing = mean(diff(sort(refLevels, 'descend')));
        if minDist < 0.1 * refSpacing
            confidence(i) = min(1, confidence(i) + 0.2);
        end
    end
    
    % Store info for visualization
    info.interpFactors = interpFactors;
    info.bracketIndices = bracketIndices;
end

%% ==================== METHOD 2: CONFIDENCE-WEIGHTED UPDATE ====================

function [pattern, confidence, info] = classifyDynamicThreshold_ConfidenceWeighted(amplitudes, referenceLevels)
    % CONFIDENCE-WEIGHTED UPDATE
    %
    % This method ADAPTS reference levels as it processes pulses:
    % 1. Classify each pulse using current reference levels
    % 2. If confidence is HIGH, slightly update the reference level
    %    towards the measured amplitude
    % 3. This allows the receiver to track slow drift in signal levels
    %
    % Update rule: ref_new = ref_old + alpha * conf * (amp - ref_old)
    % - alpha: learning rate (small, e.g., 0.1)
    % - conf: confidence (only update when confident)
    % - (amp - ref_old): error term
    %
    % Benefits:
    % - Tracks slow amplitude drift
    % - Self-correcting: high-confidence decisions reinforce good references
    % - Low-confidence decisions don't corrupt references
    
    symbolValues = [150, 120, 90, 60];
    alpha = 0.15;  % Learning rate
    confThreshold = 0.7;  % Only update if confidence above this
    
    amplitudes = amplitudes(:);
    currentRefs = referenceLevels(:)';  % Working copy of references
    
    numPulses = length(amplitudes);
    pattern = zeros(numPulses, 1);
    confidence = zeros(numPulses, 1);
    refHistory = zeros(numPulses, 4);  % Track reference evolution
    
    for i = 1:numPulses
        amp = amplitudes(i);
        
        % Calculate distances to current references
        distances = abs(amp - currentRefs);
        [minDist, closestIdx] = min(distances);
        pattern(i) = symbolValues(closestIdx);
        
        % Calculate confidence (same as basic)
        sortedDist = sort(distances);
        d1 = sortedDist(1);
        d2 = sortedDist(2);
        
        if d1 + d2 > 0
            confidence(i) = 1 - (d1 / (d1 + d2));
        else
            confidence(i) = 1;
        end
        
        % Update reference if confidence is high enough
        if confidence(i) >= confThreshold
            % Update only the closest reference
            error = amp - currentRefs(closestIdx);
            update = alpha * confidence(i) * error;
            currentRefs(closestIdx) = currentRefs(closestIdx) + update;
        end
        
        % Store reference history
        refHistory(i,:) = currentRefs;
    end
    
    % Store info for visualization
    info.refHistory = refHistory;
    info.initialRefs = referenceLevels(:)';
    info.finalRefs = currentRefs;
    info.alpha = alpha;
    info.confThreshold = confThreshold;
end

%% ==================== METHOD 3: SECOND-ORDER CONFIDENCE ====================

function [pattern, confidence, info] = classifyDynamicThreshold_SecondOrder(amplitudes, referenceLevels)
    % SECOND-ORDER CONFIDENCE
    %
    % This method uses the RATE OF CHANGE of distances to reference levels
    % to provide additional confidence information:
    %
    % First-order: distance to each reference (standard)
    % Second-order: how quickly distance changes as we move between references
    %
    % The idea: If an amplitude is in a "steep" region (far from decision
    % boundaries), small measurement errors won't change the decision.
    % If it's in a "flat" region (near a boundary), it's more uncertain.
    %
    % Implementation:
    % 1. Calculate distances to all references
    % 2. Calculate "gradient" - how fast the best choice changes
    % 3. High gradient = stable decision = high confidence
    % 4. Low gradient = near boundary = low confidence
    %
    % Gradient approximation: (d2 - d1) / d1
    % Large ratio = clear winner = confident
    % Small ratio = close call = uncertain
    
    symbolValues = [150, 120, 90, 60];
    
    amplitudes = amplitudes(:);
    refLevels = referenceLevels(:)';
    
    numPulses = length(amplitudes);
    pattern = zeros(numPulses, 1);
    confidence = zeros(numPulses, 1);
    gradients = zeros(numPulses, 1);
    marginRatios = zeros(numPulses, 1);
    
    % Calculate reference spacing for normalization
    refSpacing = abs(diff(sort(refLevels)));
    avgSpacing = mean(refSpacing);
    
    for i = 1:numPulses
        amp = amplitudes(i);
        
        % Calculate distances
        distances = abs(amp - refLevels);
        [sortedDist, sortedIdx] = sort(distances);
        
        d1 = sortedDist(1);  % Closest
        d2 = sortedDist(2);  % Second closest
        d3 = sortedDist(3);  % Third closest
        
        closestIdx = sortedIdx(1);
        pattern(i) = symbolValues(closestIdx);
        
        % First-order confidence (basic)
        if d1 + d2 > 0
            conf_firstOrder = 1 - (d1 / (d1 + d2));
        else
            conf_firstOrder = 1;
        end
        
        % Second-order: margin ratio
        % How much better is the best choice compared to second best?
        if d1 > 0
            marginRatio = (d2 - d1) / d1;
        else
            marginRatio = 10;  % Perfect match
        end
        marginRatios(i) = marginRatio;
        
        % Second-order: gradient (rate of change)
        % Compare gap between 1st-2nd vs 2nd-3rd
        gap12 = d2 - d1;
        gap23 = d3 - d2;
        
        if gap12 + gap23 > 0
            gradientFactor = gap12 / (gap12 + gap23);
        else
            gradientFactor = 0.5;
        end
        gradients(i) = gradientFactor;
        
        % Combine first-order and second-order confidence
        % Normalize margin ratio to 0-1 range
        marginConf = min(1, marginRatio / 2);  % Saturates at ratio=2
        
        % Weight: 60% first-order, 25% margin, 15% gradient
        confidence(i) = 0.60 * conf_firstOrder + ...
                        0.25 * marginConf + ...
                        0.15 * (1 - abs(gradientFactor - 0.5) * 2);
        
        % Ensure confidence is in valid range
        confidence(i) = max(0, min(1, confidence(i)));
    end
    
    % Store info for visualization
    info.gradients = gradients;
    info.marginRatios = marginRatios;
    info.avgSpacing = avgSpacing;
end

%% ==================== PULSE EXTRACTION WITH WEIGHTED CORRELATION ====================

function [pulsePositions, pulseAmps_Mean, pulseAmps_CorrNorm] = extractPulsesXCorr(signal, pulseTemplate, maxPulses)
    signal = signal(:);
    pulseTemplate = pulseTemplate(:);
    pulseWidth = length(pulseTemplate);
    templateEnergy = sum(pulseTemplate.^2);
    
    % Standard correlation for peak finding
    correlationSignal_Standard = conv(signal, flipud(pulseTemplate), 'same');
    corrNormalized = correlationSignal_Standard / max(abs(correlationSignal_Standard));
    
    % Find peaks
    minPeakHeight = 0.2;
    minPeakDistance = round(pulseWidth * 0.7);
    [~, locs] = findpeaks(corrNormalized, 'MinPeakHeight', minPeakHeight, ...
        'MinPeakDistance', minPeakDistance);
    
    numPulses = min(length(locs), maxPulses);
    pulsePositions = locs(1:numPulses);
    
    % Weighted correlation for amplitude
    sigma = pulseWidth / 4;
    x = linspace(-pulseWidth/2, pulseWidth/2, pulseWidth);
    gaussianWeight = exp(-x.^2 / (2 * sigma^2));
    gaussianWeight = gaussianWeight(:);
    weightedTemplate = pulseTemplate .* gaussianWeight;
    weightedEnergy = sum(weightedTemplate.^2);
    correlationSignal_Weighted = conv(signal, flipud(weightedTemplate), 'same');
    
    halfWidth = round(pulseWidth / 2);
    pulseAmps_Mean = zeros(numPulses, 1);
    pulseAmps_CorrNorm = zeros(numPulses, 1);
    
    for i = 1:numPulses
        pos = pulsePositions(i);
        
        startIdx = max(1, pos - halfWidth);
        endIdx = min(length(signal), pos + halfWidth);
        pulseAmps_Mean(i) = mean(signal(startIdx:endIdx));
        
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

%% ==================== FIXED THRESHOLD ====================

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

%% ==================== HAMMING DECODE ====================

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

function plotMethodComparison(dataSegment, dataPositions, dataAmps, refLevels, ...
        pat_Basic, pat_Interp, pat_ConfWt, pat_SecOrd, ...
        conf_Basic, conf_Interp, conf_ConfWt, conf_SecOrd, ...
        BER_Basic, BER_Interp, BER_ConfWt, BER_SecOrd, ...
        interpInfo, confWeightInfo, secondOrderInfo, pulseTemplate)
    
    figure('Name', 'Dynamic Thresholding Methods Comparison', 'Position', [30 30 1600 900]);
    
    colors = struct('Basic', [0.2 0.4 0.8], 'Interp', [0.8 0.4 0.2], ...
                   'ConfWt', [0.2 0.7 0.3], 'SecOrd', [0.7 0.2 0.7]);
    
    symbolMap = [150, 120, 90, 60];
    
    %% Row 1: Method-specific visualizations
    
    % Plot 1: Amplitudes vs Reference Levels
    subplot(3,4,1);
    bar(dataAmps, 'FaceColor', [0.5 0.5 0.5]);
    hold on;
    refColors = {'r', 'm', 'c', 'b'};
    for j = 1:4
        yline(refLevels(j), '--', 'Color', refColors{j}, 'LineWidth', 2);
    end
    xlabel('Pulse'); ylabel('Amplitude');
    title('Amplitudes vs Reference Levels');
    legend('Amp', '150', '120', '90', '60', 'Location', 'best');
    grid on;
    
    % Plot 2: Reference Interpolation - Interpolation factors
    subplot(3,4,2);
    bar(interpInfo.interpFactors, 'FaceColor', colors.Interp);
    hold on;
    yline(0.5, 'r--', 'LineWidth', 2);
    xlabel('Pulse'); ylabel('Interpolation Factor');
    title('Method 1: Interpolation Factors');
    ylim([0 1]);
    legend('t factor', 'Ambiguous (0.5)');
    grid on;
    
    % Plot 3: Confidence-Weighted - Reference Evolution
    subplot(3,4,3);
    hold on;
    for j = 1:4
        plot(confWeightInfo.refHistory(:,j), 'LineWidth', 2);
    end
    xlabel('Pulse'); ylabel('Reference Level');
    title('Method 2: Reference Evolution');
    legend('Ref 150', 'Ref 120', 'Ref 90', 'Ref 60');
    grid on;
    
    % Plot 4: Second-Order - Margin Ratios
    subplot(3,4,4);
    bar(secondOrderInfo.marginRatios, 'FaceColor', colors.SecOrd);
    hold on;
    yline(1, 'g--', 'LineWidth', 2);
    yline(0.5, 'r--', 'LineWidth', 2);
    xlabel('Pulse'); ylabel('Margin Ratio');
    title('Method 3: Margin Ratios (d2-d1)/d1');
    legend('Ratio', 'Good (1)', 'Poor (0.5)');
    grid on;
    
    %% Row 2: Pattern and Confidence Comparison
    
    % Plot 5: Pattern Comparison
    subplot(3,4,5);
    patIdx_Basic = arrayfun(@(x) find(symbolMap == x, 1), pat_Basic);
    patIdx_Interp = arrayfun(@(x) find(symbolMap == x, 1), pat_Interp);
    patIdx_ConfWt = arrayfun(@(x) find(symbolMap == x, 1), pat_ConfWt);
    patIdx_SecOrd = arrayfun(@(x) find(symbolMap == x, 1), pat_SecOrd);
    
    x = 1:length(pat_Basic);
    width = 0.2;
    bar(x - 1.5*width, patIdx_Basic, width, 'FaceColor', colors.Basic);
    hold on;
    bar(x - 0.5*width, patIdx_Interp, width, 'FaceColor', colors.Interp);
    bar(x + 0.5*width, patIdx_ConfWt, width, 'FaceColor', colors.ConfWt);
    bar(x + 1.5*width, patIdx_SecOrd, width, 'FaceColor', colors.SecOrd);
    ylim([0.5 4.5]);
    yticks(1:4); yticklabels({'150', '120', '90', '60'});
    xlabel('Pulse'); ylabel('Symbol');
    title('Pattern Comparison');
    legend('Basic', 'Interp', 'ConfWt', 'SecOrd', 'Location', 'best');
    grid on;
    
    % Plot 6: Confidence Comparison
    subplot(3,4,6);
    bar(x - 1.5*width, conf_Basic*100, width, 'FaceColor', colors.Basic);
    hold on;
    bar(x - 0.5*width, conf_Interp*100, width, 'FaceColor', colors.Interp);
    bar(x + 0.5*width, conf_ConfWt*100, width, 'FaceColor', colors.ConfWt);
    bar(x + 1.5*width, conf_SecOrd*100, width, 'FaceColor', colors.SecOrd);
    yline(60, 'r--', 'LineWidth', 2);
    xlabel('Pulse'); ylabel('Confidence (%)');
    title('Confidence Comparison');
    ylim([0 100]);
    legend('Basic', 'Interp', 'ConfWt', 'SecOrd', 'Threshold', 'Location', 'best');
    grid on;
    
    % Plot 7: Average Confidence by Method
    subplot(3,4,7);
    avgConfs = [mean(conf_Basic), mean(conf_Interp), mean(conf_ConfWt), mean(conf_SecOrd)] * 100;
    b = bar(avgConfs);
    b.FaceColor = 'flat';
    b.CData = [colors.Basic; colors.Interp; colors.ConfWt; colors.SecOrd];
    xticklabels({'Basic', 'Interp', 'ConfWt', 'SecOrd'});
    ylabel('Average Confidence (%)');
    title('Average Confidence');
    ylim([0 100]);
    grid on;
    
    % Plot 8: BER Comparison
    subplot(3,4,8);
    BERs = [BER_Basic, BER_Interp, BER_ConfWt, BER_SecOrd] * 100;
    b = bar(BERs);
    b.FaceColor = 'flat';
    b.CData = [colors.Basic; colors.Interp; colors.ConfWt; colors.SecOrd];
    xticklabels({'Basic', 'Interp', 'ConfWt', 'SecOrd'});
    ylabel('BER (%)');
    title('Bit Error Rate');
    grid on;
    
    %% Row 3: Detailed Analysis
    
    % Plot 9: Confidence Difference from Basic
    subplot(3,4,9);
    confDiff_Interp = (conf_Interp - conf_Basic) * 100;
    confDiff_ConfWt = (conf_ConfWt - conf_Basic) * 100;
    confDiff_SecOrd = (conf_SecOrd - conf_Basic) * 100;
    
    bar(x - 0.3, confDiff_Interp, 0.3, 'FaceColor', colors.Interp);
    hold on;
    bar(x, confDiff_ConfWt, 0.3, 'FaceColor', colors.ConfWt);
    bar(x + 0.3, confDiff_SecOrd, 0.3, 'FaceColor', colors.SecOrd);
    yline(0, 'k-', 'LineWidth', 1);
    xlabel('Pulse'); ylabel('Confidence Δ from Basic (%)');
    title('Confidence Improvement over Basic');
    legend('Interp', 'ConfWt', 'SecOrd');
    grid on;
    
    % Plot 10: Pattern Agreement Heatmap
    subplot(3,4,10);
    patterns = [pat_Basic, pat_Interp, pat_ConfWt, pat_SecOrd];
    agreement = zeros(length(pat_Basic), 1);
    for i = 1:length(pat_Basic)
        agreement(i) = sum(patterns(i,:) == mode(patterns(i,:))) / 4;
    end
    bar(agreement * 100, 'FaceColor', [0.3 0.6 0.3]);
    hold on;
    yline(75, 'y--', 'LineWidth', 2);
    yline(100, 'g--', 'LineWidth', 2);
    xlabel('Pulse'); ylabel('Agreement (%)');
    title('Method Agreement per Pulse');
    ylim([0 100]);
    legend('Agreement', '75%', '100%');
    grid on;
    
    % Plot 11: Score Comparison
    subplot(3,4,11);
    scores = [mean(conf_Basic) - BER_Basic*100, ...
              mean(conf_Interp) - BER_Interp*100, ...
              mean(conf_ConfWt) - BER_ConfWt*100, ...
              mean(conf_SecOrd) - BER_SecOrd*100];
    b = bar(scores);
    b.FaceColor = 'flat';
    b.CData = [colors.Basic; colors.Interp; colors.ConfWt; colors.SecOrd];
    xticklabels({'Basic', 'Interp', 'ConfWt', 'SecOrd'});
    ylabel('Score (Conf - BER×100)');
    title('Overall Score (Higher = Better)');
    grid on;
    
    % Highlight best
    [~, bestIdx] = max(scores);
    hold on;
    bar(bestIdx, scores(bestIdx), 'FaceColor', 'g', 'EdgeColor', 'k', 'LineWidth', 2);
    
    % Plot 12: Summary
    subplot(3,4,12);
    axis off;
    
    text(0.05, 0.95, 'METHOD SUMMARY', 'FontSize', 12, 'FontWeight', 'bold');
    
    text(0.05, 0.82, '1. REFERENCE INTERPOLATION:', 'FontSize', 10, 'FontWeight', 'bold', 'Color', colors.Interp);
    text(0.05, 0.74, '   Uses position between refs for confidence', 'FontSize', 8);
    text(0.05, 0.66, sprintf('   Avg Conf: %.1f%% | BER: %.4f', mean(conf_Interp)*100, BER_Interp), 'FontSize', 8);
    
    text(0.05, 0.54, '2. CONFIDENCE-WEIGHTED UPDATE:', 'FontSize', 10, 'FontWeight', 'bold', 'Color', colors.ConfWt);
    text(0.05, 0.46, '   Adapts references based on confidence', 'FontSize', 8);
    text(0.05, 0.38, sprintf('   Avg Conf: %.1f%% | BER: %.4f', mean(conf_ConfWt)*100, BER_ConfWt), 'FontSize', 8);
    
    text(0.05, 0.26, '3. SECOND-ORDER CONFIDENCE:', 'FontSize', 10, 'FontWeight', 'bold', 'Color', colors.SecOrd);
    text(0.05, 0.18, '   Uses margin ratio for stability measure', 'FontSize', 8);
    text(0.05, 0.10, sprintf('   Avg Conf: %.1f%% | BER: %.4f', mean(conf_SecOrd)*100, BER_SecOrd), 'FontSize', 8);
    
    methods = {'Basic', 'Interp', 'ConfWt', 'SecOrd'};
    [~, bestIdx] = max(scores);
    text(0.05, 0.02, sprintf('★ BEST: %s', methods{bestIdx}), 'FontSize', 11, 'FontWeight', 'bold', 'Color', 'g');
    
    sgtitle('Dynamic Thresholding Methods Comparison', 'FontSize', 14, 'FontWeight', 'bold');
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