clc;
close all;


% bin data path
binDataPath = '.\Data\';  
binDataDir = dir([binDataPath,'*.bin']);

fileCount = length(binDataDir);
fprintf('bin data%s\n', binDataDir.name);

%bin to matData
for fileId = 1 : 1 :fileCount

    fileName = binDataDir(fileId).name
    disp(['----------',num2str(fileId),'------------']);
    sourceDataFile = [binDataPath, fileName]

    binPath = binDataPath(1:end-1);
    readerRawData('.\setting\18xx.setup.json',fileName,binPath); 

end


matDataPath = [binDataPath,'matData\'];
matDataDir = dir([matDataPath,'*.mat']);
fileCount = length(matDataDir);



% target vibration frequecy

sigFre = [100,300];

% target location
% trueLoc =  0.31; // for the .bin file in the drive
trueLoc =  0.31;


for fileId = 1: 1 : fileCount

    fileName = matDataDir(fileId).name;
    fprintf("filename %s",fileName);
    disp(['----------',num2str(fileId),'------------']);
    matDataFile = [matDataPath, fileName];

    % target path
    saveTargetPath=[matDataPath,'Proced\'];
    mkdir(saveTargetPath);
    saveData = [saveTargetPath, fileName(1:end-4)];
    
    % initialization
    radarCube = [];

    % load mat Data
    load(matDataFile);


    if (isempty(radarCube))
      fprintf("ERROR -- on radarCube"); 
      break;
    end   

    rangeFFT_x = radarCube.rfParams.rangeFFT_x;


    [radarCube] = getTargetSignal(radarCube);

    % find target bin
    diff_distance = abs(rangeFFT_x-trueLoc);
    [min_distance, idx] = min(diff_distance); % Get the minimum distance and its index

    % Print the minimum distance
    fprintf('Minimum distance: %f idx: %f', min_distance,idx);
    
    % target signal
    signal = radarCube.targetSignal(:,:,idx);
    angle = 0;


    % vibration signal
    vibSig = getVibSig(signal,angle,sigFre,fileName);


    end



