%% BLE Tree vs Managed-Flooding Mesh Sensitivity Experiments
% Paper: "When Is Managed-Flooding BLE Mesh Better Than BLE Tree?"
% Standalone MATLAB R2025b script; no specialized toolbox required.
%
% This script performs the sensitivity analyses used in the paper.
%
% TASKS
%   1) Communication-model sensitivity:
%      receiver-local contention + correlated advertising-channel collisions.
%   2) Transient, persistent-independent, and spatially correlated unavailability.
%   3) Tree retry/reconstruction sensitivity under persistent unavailability.
%   4) Receiver/listening-duty-cycle energy sensitivity for both architectures.
%   5) Reliability-constrained crossover over BOTH load lambda and p_f.
%   6) Geometry/path-loss/hop-count sensitivity + paired validation across N.
%   7) Alternative Tree-parent and Mesh-relay/TTL/retransmission policies.
%
% OUTPUT
%   ./sensitivity_results/*.csv       numerical results
%   ./sensitivity_results/*.pdf/png   publication-preview figures
%   ./sensitivity_results/*.fig       editable MATLAB figures (optional)
%   ./sensitivity_results/*.mat       per-task checkpoints
%   ./sensitivity_results/config.txt  complete frozen configuration
%
% IMPORTANT
%   - quickMode=true is ONLY a smoke test. Do not use quick-mode numbers in
%     the reported results.
%   - The full run uses paired topology/channel/unavailability realizations
%     whenever architectures are directly compared.
%   - The script uses print() rather than exportgraphics(), because the latter
%     caused graphics-export hangs in the earlier workflow.

clc; close all;

%% ---------------------------- USER SWITCHES -----------------------------
quickMode = false;             % full sensitivity run; Task 1 resumes from existing checkpoint
resumeCompletedTasks = true;   % reuse checkpoint MAT files if they exist
exportPlots = true;            % figures are generated AFTER each task finishes
saveFigFiles = true;           % quickMode forces this false; full mode saves editable .fig files

runTask = true(1,7);           % set individual entries false if rerunning selectively
if quickMode
    outDir = 'sensitivity_results_quick';
else
    outDir = 'sensitivity_results';
end
if ~exist(outDir,'dir'), mkdir(outDir); end

cfg = defaultConfig();
cfg.quickMode = quickMode;
cfg.outDir = outDir;
cfg.exportPlots = exportPlots;
if quickMode, saveFigFiles=false; end
cfg.saveFigFiles = saveFigFiles;

if quickMode
    % Tiny smoke-test counts. These are intentionally NOT statistically useful.
    cfg.nComm = 2;
    cfg.nFail = 2;
    cfg.nTreeRecovery = 2;
    cfg.nDuty = 2;
    cfg.nLoadMap = 2;
    cfg.nGeom = 2;
    cfg.nPair = 2;
    cfg.nPolicy = 2;
else
    % Full-study counts. Increase only if a particular curve needs a
    % narrower confidence interval after inspecting the first full run.
    cfg.nComm = 100;
    cfg.nFail = 120;
    cfg.nTreeRecovery = 120;
    cfg.nDuty = 100;
    cfg.nLoadMap = 80;
    cfg.nGeom = 80;
    cfg.nPair = 120;
    cfg.nPolicy = 100;
end

fprintf('\nIEEE Networking Letters sensitivity experiment driver\n');
fprintf('quickMode = %d\n',quickMode);
fprintf('Output directory: %s\n',outDir);
fprintf('Base seed: %d\n\n',cfg.seed);
writeConfig(cfg,fullfile(outDir,'sensitivity_config.txt'));

%% =======================================================================
% TASK 1. Communication-model sensitivity
% ========================================================================
% Compare the baseline approximation against a receiver-local contention
% model and progressively stronger correlation of collision states across
% advertising channels 37/38/39.
if runTask(1)
    chk = fullfile(outDir,'task1_communication_model.mat');
    if resumeCompletedTasks && exist(chk,'file')==2
        load(chk,'T1');
        fprintf('Task 1 loaded from checkpoint.\n');
    else
        fprintf('\nTASK 1/7: communication-model sensitivity\n');
        if quickMode
            lambdaVec = [0.1 2];
            modelNames = {'Global-independent','Local-correlated'};
            contention = {'global','local'};
            rhoVec = [0 1];
        else
            lambdaVec = [0.02 0.1 0.5 1 2];
            modelNames = {'Global-independent','Local-independent', ...
                'Local-rho0.5','Local-fully-correlated'};
            contention = {'global','local','local','local'};
            rhoVec = [0 0 0.5 1];
        end
        rows = [];
        for im = 1:numel(modelNames)
            for il = 1:numel(lambdaVec)
                comm = makeCommSpec(contention{im},rhoVec(im));
                fprintf('  model=%s, lambda=%.3g\n',modelNames{im},lambdaVec(il));
                [t,m] = runPointEnhanced(cfg.Ndefault,cfg.pFailDefault,lambdaVec(il), ...
                    cfg,cfg.nComm,cfg.seed+100000+il,comm, ...
                    makeFailureSpec('transient'),makeTreeSpec(),makeMeshSpec());
                rows = [rows; im il lambdaVec(il) rhoVec(im) ... %#ok<AGROW>
                    t.PDR t.PDRCI m.PDR m.PDRCI 1e6*t.Esucc 1e6*m.Esucc ...
                    t.Enet_mJ m.Enet_mJ t.meanHop m.meanHop];
            end
        end
        T1 = array2table(rows,'VariableNames',{'ModelID','LambdaIndex','lambda','ChannelCollisionCorrelation', ...
            'TreePDR','TreePDR_CI95','MeshPDR','MeshPDR_CI95','TreeEnergy_uJ','MeshEnergy_uJ', ...
            'TreeRoundEnergy_mJ','MeshRoundEnergy_mJ','TreeMeanHop','MeshMeanDepth'});
        T1.Model = reshape(string(modelNames(T1.ModelID)),[],1);
        writetable(T1,fullfile(outDir,'task1_communication_model_sensitivity.csv'));
        save(chk,'T1','modelNames','lambdaVec');
    end
    if exportPlots
        plotTask1(T1,outDir,saveFigFiles);
    end
end

%% =======================================================================
% TASK 2. Transient / persistent / spatially correlated unavailability
% ========================================================================
if runTask(2)
    chk = fullfile(outDir,'task2_failure_models.mat');
    if resumeCompletedTasks && exist(chk,'file')==2
        load(chk,'T2');
        fprintf('Task 2 loaded from checkpoint.\n');
    else
        fprintf('\nTASK 2/7: failure/unavailability-model sensitivity\n');
        if quickMode
            pfVec = [0.10 0.20];
            modes = {'transient','persistent-independent'};
        else
            pfVec = [0.05 0.10 0.15 0.20 0.30 0.40];
            modes = {'transient','persistent-independent','persistent-correlated'};
        end
        comm = makeCommSpec('local',1.0);  % conservative correlated-event sensitivity model
        rows = [];
        for im = 1:numel(modes)
            fs = makeFailureSpec(modes{im});
            for ip = 1:numel(pfVec)
                fprintf('  mode=%s, p_f=%.2f\n',modes{im},pfVec(ip));
                [t,m] = runPointEnhanced(cfg.Ndefault,pfVec(ip),cfg.lambdaDefault, ...
                    cfg,cfg.nFail,cfg.seed+200000+ip,comm,fs, ...
                    makeTreeSpec(),makeMeshSpec());
                rows = [rows; im pfVec(ip) t.PDR t.PDRCI m.PDR m.PDRCI ... %#ok<AGROW>
                    1e6*t.Esucc 1e6*m.Esucc t.Enet_mJ m.Enet_mJ];
            end
        end
        T2 = array2table(rows,'VariableNames',{'ModeID','pFail','TreePDR','TreePDR_CI95', ...
            'MeshPDR','MeshPDR_CI95','TreeEnergy_uJ','MeshEnergy_uJ','TreeRoundEnergy_mJ','MeshRoundEnergy_mJ'});
        T2.FailureMode = reshape(string(modes(T2.ModeID)),[],1);
        writetable(T2,fullfile(outDir,'task2_failure_model_sensitivity.csv'));
        save(chk,'T2','modes','pfVec');
    end
    if exportPlots
        plotTask2(T2,outDir,saveFigFiles);
    end
end

%% =======================================================================
% TASK 3. Tree retry and reconstruction under persistent unavailability
% ========================================================================
if runTask(3)
    chk = fullfile(outDir,'task3_tree_recovery.mat');
    if resumeCompletedTasks && exist(chk,'file')==2
        load(chk,'T3');
        fprintf('Task 3 loaded from checkpoint.\n');
    else
        fprintf('\nTASK 3/7: Tree retry/reconstruction sensitivity\n');
        if quickMode
            pfVec = [0.10 0.20];
        else
            pfVec = [0.05 0.10 0.15 0.20 0.25 0.30];
        end
        treeNames = {'No-retry/no-repair','One-retry/no-repair','One-retry/reconstruct'};
        treeSpecs = {makeTreeSpec(0,false,'minhop-battery'), ...
                     makeTreeSpec(1,false,'minhop-battery'), ...
                     makeTreeSpec(1,true,'minhop-battery')};
        comm = makeCommSpec('local',1.0);
        fs = makeFailureSpec('persistent-independent');
        rows = [];
        for it = 1:numel(treeSpecs)
            for ip = 1:numel(pfVec)
                fprintf('  Tree=%s, p_f=%.2f\n',treeNames{it},pfVec(ip));
                [t,m] = runPointEnhanced(cfg.Ndefault,pfVec(ip),cfg.lambdaDefault, ...
                    cfg,cfg.nTreeRecovery,cfg.seed+300000+ip,comm,fs, ...
                    treeSpecs{it},makeMeshSpec());
                rows = [rows; it pfVec(ip) t.PDR t.PDRCI 1e6*t.Esucc 1e6*t.EsuccCI ... %#ok<AGROW>
                    t.Enet_mJ m.PDR m.PDRCI 1e6*m.Esucc];
            end
        end
        T3 = array2table(rows,'VariableNames',{'TreeConfigID','pFail','TreePDR','TreePDR_CI95', ...
            'TreeEnergy_uJ','TreeEnergy_CI95_uJ','TreeRoundEnergy_mJ','MeshPDR','MeshPDR_CI95','MeshEnergy_uJ'});
        T3.TreeConfiguration = reshape(string(treeNames(T3.TreeConfigID)),[],1);
        writetable(T3,fullfile(outDir,'task3_tree_retry_reconstruction.csv'));
        save(chk,'T3','treeNames','pfVec');
    end
    if exportPlots
        plotTask3(T3,outDir,saveFigFiles,cfg.reliabilityTarget);
    end
end

%% =======================================================================
% TASK 4. Receiver/listening-duty-cycle energy sensitivity
% ========================================================================
% Dynamic radio-event counts are simulated once per trial. Listening energy
% is then added analytically for a grid of Tree-parent and Mesh-relay receive
% duty factors, so this task is inexpensive.
if runTask(4)
    chk = fullfile(outDir,'task4_duty_cycle.mat');
    if resumeCompletedTasks && exist(chk,'file')==2
        load(chk,'T4');
        fprintf('Task 4 loaded from checkpoint.\n');
    else
        fprintf('\nTASK 4/7: receiver duty-cycle energy sensitivity\n');
        if quickMode
            dutyTree = [0.01 0.10];
            dutyMesh = [0.01 0.10];
        else
            dutyTree = [0.005 0.01 0.02 0.05 0.10 0.20];
            dutyMesh = [0.005 0.01 0.02 0.05 0.10 0.20];
        end
        comm = makeCommSpec('local',1.0);
        fs = makeFailureSpec('transient');
        [trialTree,trialMesh] = collectDutyTrials(cfg.Ndefault,0,cfg.lambdaDefault, ...
            cfg,cfg.nDuty,cfg.seed+400000,comm,fs,makeTreeSpec(),makeMeshSpec());
        rows = [];
        roundDuration = 1/cfg.lambdaDefault;  % expected time between network rounds
        for it = 1:numel(dutyTree)
            for im = 1:numel(dutyMesh)
                treeE = trialTree.dynamicRound_J + trialTree.listenerCount*cfg.V*cfg.I_rx*dutyTree(it)*roundDuration;
                meshE = trialMesh.dynamicRound_J + trialMesh.listenerCount*cfg.V*cfg.I_rx*dutyMesh(im)*roundDuration;
                treeEsucc = treeE ./ max(trialTree.delivered,1);
                meshEsucc = meshE ./ max(trialMesh.delivered,1);
                rows = [rows; dutyTree(it) dutyMesh(im) 1e3*mean(treeE) 1e3*mean(meshE) ... %#ok<AGROW>
                    1e6*mean(treeEsucc) 1e6*mean(meshEsucc) mean(meshEsucc./treeEsucc) ...
                    mean(trialTree.listenerCount) mean(trialMesh.listenerCount)];
            end
        end
        T4 = array2table(rows,'VariableNames',{'TreeReceiveDuty','MeshReceiveDuty','TreeRoundEnergy_mJ', ...
            'MeshRoundEnergy_mJ','TreeEnergyPerDelivered_uJ','MeshEnergyPerDelivered_uJ', ...
            'MeshToTreeEnergyRatio','MeanTreeListeningNodes','MeanMeshListeningNodes'});
        writetable(T4,fullfile(outDir,'task4_receiver_duty_cycle_sensitivity.csv'));
        save(chk,'T4','dutyTree','dutyMesh');
    end
    if exportPlots
        plotTask4(T4,outDir,saveFigFiles);
    end
end

%% =======================================================================
% TASK 5. Crossover over BOTH lambda and p_f
% ========================================================================
% Uses the conservative sensitivity communication model (receiver-local load,
% fully correlated collision state across the three advertising copies) and
% a strengthened Tree with one repeated advertising event per hop.
if runTask(5)
    chk = fullfile(outDir,'task5_load_failure_map.mat');
    if resumeCompletedTasks && exist(chk,'file')==2
        load(chk,'T5','choice5','lambdaVec5','pfVec5');
        fprintf('Task 5 loaded from checkpoint.\n');
    else
        fprintf('\nTASK 5/7: load-dependent reliability-constrained crossover\n');
        if quickMode
            lambdaVec5 = [0.1 2];
            pfVec5 = [0.05 0.20];
        else
            lambdaVec5 = [0.02 0.05 0.10 0.20 0.50 1 2];
            pfVec5 = 0:0.05:0.50;
        end
        comm = makeCommSpec('local',1.0);
        fs = makeFailureSpec('transient');
        ts = makeTreeSpec(1,false,'minhop-battery');
        ms = makeMeshSpec();
        rows = [];
        choice5 = zeros(numel(lambdaVec5),numel(pfVec5));
        for il = 1:numel(lambdaVec5)
            for ip = 1:numel(pfVec5)
                fprintf('  lambda=%.3g, p_f=%.2f\n',lambdaVec5(il),pfVec5(ip));
                [t,m] = runPointEnhanced(cfg.Ndefault,pfVec5(ip),lambdaVec5(il),cfg, ...
                    cfg.nLoadMap,cfg.seed+500000+100*il+ip,comm,fs,ts,ms);
                ch = classifyOne(t,m,cfg.reliabilityTarget);
                choice5(il,ip)=ch;
                rows = [rows; lambdaVec5(il) pfVec5(ip) t.PDR t.PDRCI m.PDR m.PDRCI ... %#ok<AGROW>
                    1e6*t.Esucc 1e6*m.Esucc ch];
            end
        end
        T5 = array2table(rows,'VariableNames',{'lambda','pFail','TreePDR','TreePDR_CI95', ...
            'MeshPDR','MeshPDR_CI95','TreeEnergy_uJ','MeshEnergy_uJ','ChoiceCode'});
        writetable(T5,fullfile(outDir,'task5_load_failure_crossover.csv'));
        writematrix(choice5,fullfile(outDir,'task5_choice_matrix.csv'));
        save(chk,'T5','choice5','lambdaVec5','pfVec5');
    end
    if exportPlots
        plotTask5(choice5,lambdaVec5,pfVec5,outDir,saveFigFiles);
    end
end

%% =======================================================================
% TASK 6. Geometry/path-loss/hop-count sensitivity + paired check across N
% ========================================================================
if runTask(6)
    chk = fullfile(outDir,'task6_geometry_hops.mat');
    if resumeCompletedTasks && exist(chk,'file')==2
        load(chk,'T6','T6pair');
        fprintf('Task 6 loaded from checkpoint.\n');
    else
        fprintf('\nTASK 6/7: geometry, propagation and hop-count sensitivity\n');
        if quickMode
            areaVec = [100 150];
            alphaVec = 3.0;
            pfGeom = [0.10 0.20];
            Npair = [80 160];
        else
            areaVec = [75 100 125 150];
            alphaVec = [2.5 3.0 3.5];
            pfGeom = 0.05:0.025:0.25;
            Npair = [40 80 120 160 200];
        end
        comm = makeCommSpec('local',1.0);
        fs = makeFailureSpec('transient');
        ts = makeTreeSpec(1,false,'minhop-battery');
        ms = makeMeshSpec();
        rows = cell(0,14);
        settingID = 0;
        % One-factor-at-a-time area sweep at alpha=3.
        for ia = 1:numel(areaVec)
            settingID=settingID+1;
            cfgG=cfg; cfgG.areaSide=areaVec(ia); cfgG.pathLossExp=3.0;
            rows = [rows; runGeometrySetting(settingID,'Area',areaVec(ia),cfgG,pfGeom, ... %#ok<AGROW>
                cfg.nGeom,cfg.seed+600000,comm,fs,ts,ms)];
        end
        % One-factor-at-a-time path-loss sweep at area=100; skip duplicate alpha=3 if already represented.
        for ialpha = 1:numel(alphaVec)
            if abs(alphaVec(ialpha)-3.0)<1e-12, continue; end
            settingID=settingID+1;
            cfgG=cfg; cfgG.areaSide=100; cfgG.pathLossExp=alphaVec(ialpha);
            rows = [rows; runGeometrySetting(settingID,'PathLossExponent',alphaVec(ialpha),cfgG,pfGeom, ... %#ok<AGROW>
                cfg.nGeom,cfg.seed+600000,comm,fs,ts,ms)];
        end
        T6 = cell2table(rows,'VariableNames',{'SettingID','SweepType','SweepValue','pFail', ...
            'TreePDR','TreePDR_CI95','MeshPDR','MeshPDR_CI95','TreeEnergy_uJ','MeshEnergy_uJ', ...
            'MeanTreeHop','P90TreeHop','DirectSourceFraction','TreeCrossingEstimate'});
        writetable(T6,fullfile(outDir,'task6_geometry_hop_sensitivity.csv'));

        % Paired-mask validation across the same N values used in the baseline high-trial study.
        pfPair = [0.10 0.15];
        pairRows=[];
        for iN=1:numel(Npair)
            for ip=1:numel(pfPair)
                fprintf('  paired validation N=%d, p_f=%.2f\n',Npair(iN),pfPair(ip));
                [t,m] = runPointEnhanced(Npair(iN),pfPair(ip),cfg.lambdaDefault,cfg,cfg.nPair, ...
                    cfg.seed+610000+100*Npair(iN)+ip,comm,fs,ts,ms);
                pairRows=[pairRows; Npair(iN) pfPair(ip) t.PDR t.PDRCI m.PDR m.PDRCI ... %#ok<AGROW>
                    1e6*t.Esucc 1e6*m.Esucc];
            end
        end
        T6pair=array2table(pairRows,'VariableNames',{'N','pFail','TreePDR','TreePDR_CI95', ...
            'MeshPDR','MeshPDR_CI95','TreeEnergy_uJ','MeshEnergy_uJ'});
        writetable(T6pair,fullfile(outDir,'task6_paired_failure_across_N.csv'));
        save(chk,'T6','T6pair','areaVec','alphaVec','pfGeom');
    end
    if exportPlots
        plotTask6(T6,outDir,saveFigFiles,cfg.reliabilityTarget);
    end
end

%% =======================================================================
% TASK 7. Alternative Tree and Mesh policies
% ========================================================================
if runTask(7)
    chk = fullfile(outDir,'task7_policy_sensitivity.mat');
    if resumeCompletedTasks && exist(chk,'file')==2
        load(chk,'T7tree','T7relay','T7ttl','T7repeat');
        fprintf('Task 7 loaded from checkpoint.\n');
    else
        fprintf('\nTASK 7/7: alternative Tree/Mesh policy sensitivity\n');
        comm = makeCommSpec('local',1.0);
        fs = makeFailureSpec('transient');
        pf = 0.15;

        % 7A Tree parent policy
        treePolicies={'minhop-battery','minhop-link','minhop-hybrid'};
        rows=[];
        for i=1:numel(treePolicies)
            fprintf('  Tree policy=%s\n',treePolicies{i});
            ts=makeTreeSpec(1,false,treePolicies{i});
            [t,m]=runPointEnhanced(cfg.Ndefault,pf,cfg.lambdaDefault,cfg,cfg.nPolicy, ...
                cfg.seed+700000,comm,fs,ts,makeMeshSpec());
            rows=[rows; i t.PDR t.PDRCI 1e6*t.Esucc 1e6*t.EsuccCI t.meanHop m.PDR]; %#ok<AGROW>
        end
        T7tree=array2table(rows,'VariableNames',{'PolicyID','TreePDR','TreePDR_CI95','TreeEnergy_uJ', ...
            'TreeEnergy_CI95_uJ','MeanHop','MeshReferencePDR'});
        T7tree.Policy=reshape(string(treePolicies(T7tree.PolicyID)),[],1);
        writetable(T7tree,fullfile(outDir,'task7a_tree_parent_policy.csv'));

        % 7B Mesh relay-selection strategy
        relayStrategies={'degree','battery','random'};
        rows=[];
        for i=1:numel(relayStrategies)
            fprintf('  Mesh relay strategy=%s\n',relayStrategies{i});
            ms=makeMeshSpec(6,1,relayStrategies{i});
            [t,m]=runPointEnhanced(cfg.Ndefault,pf,cfg.lambdaDefault,cfg,cfg.nPolicy, ...
                cfg.seed+710000,comm,fs,makeTreeSpec(1,false,'minhop-battery'),ms);
            rows=[rows; i m.PDR m.PDRCI 1e6*m.Esucc 1e6*m.EsuccCI m.txEvents m.rxEvents t.PDR]; %#ok<AGROW>
        end
        T7relay=array2table(rows,'VariableNames',{'StrategyID','MeshPDR','MeshPDR_CI95','MeshEnergy_uJ', ...
            'MeshEnergy_CI95_uJ','MeshTxEvents','MeshRxEvents','TreeReferencePDR'});
        T7relay.Strategy=reshape(string(relayStrategies(T7relay.StrategyID)),[],1);
        writetable(T7relay,fullfile(outDir,'task7b_mesh_relay_strategy.csv'));

        % 7C TTL sensitivity
        ttlVec=[4 6 8]; if quickMode, ttlVec=[4 6]; end
        rows=[];
        for i=1:numel(ttlVec)
            fprintf('  Mesh TTL=%d\n',ttlVec(i));
            ms=makeMeshSpec(ttlVec(i),1,'degree');
            [~,m]=runPointEnhanced(cfg.Ndefault,pf,cfg.lambdaDefault,cfg,cfg.nPolicy, ...
                cfg.seed+720000,comm,fs,makeTreeSpec(1,false,'minhop-battery'),ms);
            rows=[rows; ttlVec(i) m.PDR m.PDRCI 1e6*m.Esucc 1e6*m.EsuccCI m.txEvents m.rxEvents]; %#ok<AGROW>
        end
        T7ttl=array2table(rows,'VariableNames',{'TTL','MeshPDR','MeshPDR_CI95','MeshEnergy_uJ', ...
            'MeshEnergy_CI95_uJ','MeshTxEvents','MeshRxEvents'});
        writetable(T7ttl,fullfile(outDir,'task7c_mesh_ttl.csv'));

        % 7D Relay retransmission sensitivity
        repeatVec=[1 2 3]; if quickMode, repeatVec=[1 2]; end
        rows=[];
        for i=1:numel(repeatVec)
            fprintf('  Mesh relay transmissions per decoded message=%d\n',repeatVec(i));
            ms=makeMeshSpec(6,repeatVec(i),'degree');
            [~,m]=runPointEnhanced(cfg.Ndefault,pf,cfg.lambdaDefault,cfg,cfg.nPolicy, ...
                cfg.seed+730000,comm,fs,makeTreeSpec(1,false,'minhop-battery'),ms);
            rows=[rows; repeatVec(i) m.PDR m.PDRCI 1e6*m.Esucc 1e6*m.EsuccCI m.txEvents m.rxEvents]; %#ok<AGROW>
        end
        T7repeat=array2table(rows,'VariableNames',{'RelayTransmissions','MeshPDR','MeshPDR_CI95','MeshEnergy_uJ', ...
            'MeshEnergy_CI95_uJ','MeshTxEvents','MeshRxEvents'});
        writetable(T7repeat,fullfile(outDir,'task7d_mesh_retransmission.csv'));
        save(chk,'T7tree','T7relay','T7ttl','T7repeat');
    end
    if exportPlots
        plotTask7(T7tree,T7relay,T7ttl,T7repeat,outDir,saveFigFiles);
    end
end

fprintf('\n============================================================\n');
fprintf('Sensitivity experiment driver complete.\n');
fprintf('Upload the entire "%s" folder for manuscript/response analysis.\n',outDir);
fprintf('============================================================\n');

%% ============================== FUNCTIONS ==============================
function cfg=defaultConfig()
    cfg.seed=17;
    cfg.areaSide=100;
    cfg.txPower_dBm=0;
    cfg.PL0_dB=40;
    cfg.d0=1;
    cfg.pathLossExp=3.0;
    cfg.sigmaShadow_dB=3.0;
    cfg.sigmaFast_dB=2.5;
    cfg.rxThreshold_dBm=-90;

    cfg.airBytes=47;
    cfg.phyRate=1e6;
    cfg.advChannels=3;
    cfg.V=3.0;
    cfg.I_tx=4.8e-3;
    cfg.I_rx=4.6e-3;
    cfg.I_sleep=2e-6;
    cfg.battery_mAh=235;
    cfg.batteryResidualRange=[0.85 1.00];
    cfg.tPDU=8*cfg.airBytes/cfg.phyRate;
    cfg.EtxEvent=cfg.advChannels*cfg.V*cfg.I_tx*cfg.tPDU;
    cfg.ErxEvent=cfg.V*cfg.I_rx*cfg.tPDU;

    cfg.meshRelayFraction=0.40;
    cfg.meshTTL=6;
    cfg.Ndefault=80;
    cfg.lambdaDefault=0.10;
    cfg.pFailDefault=0.05;
    cfg.reliabilityTarget=0.95;

    % Spatially correlated Bernoulli failure field.
    cfg.failureCorrLength_m=30;
end

function s=makeCommSpec(contention,rho)
    s.contention=contention;     % 'global' or 'local'
    s.channelCollisionCorrelation=rho; % 0 independent, 1 shared collision state
end

function s=makeFailureSpec(mode)
    s.mode=mode; % transient | persistent-independent | persistent-correlated
end

function s=makeTreeSpec(retries,reconstruct,policy)
    if nargin<1, retries=0; end
    if nargin<2, reconstruct=false; end
    if nargin<3, policy='minhop-battery'; end
    s.retries=retries;
    s.reconstruct=reconstruct;
    s.policy=policy;
end

function s=makeMeshSpec(ttl,relayTransmissions,strategy)
    if nargin<1, ttl=6; end
    if nargin<2, relayTransmissions=1; end
    if nargin<3, strategy='degree'; end
    s.ttl=ttl;
    s.relayTransmissions=relayTransmissions;
    s.relayStrategy=strategy;
end

function m=emptyMetric()
    m=struct('PDR',NaN,'PDRCI',NaN,'Esucc',NaN,'EsuccCI',NaN,'Enet_mJ',NaN, ...
        'EnetCI_mJ',NaN,'txEvents',NaN,'rxEvents',NaN,'meanHop',NaN,'meanDepth',NaN, ...
        'delivered',NaN,'listenerCount',NaN);
end

function [treeOut,meshOut]=runPointEnhanced(N,pFail,lambda,cfg,nTrials,seed,comm,failSpec,treeSpec,meshSpec)
    rng(seed,'twister');
    tv=nan(nTrials,9); mv=nan(nTrials,9);
    for tr=1:nTrials
        topo=generateTopology(N,cfg);
        topo.treeParent=buildTree(topo,treeSpec.policy,N,[]);
        topo.relayMask=chooseRelays(topo,N,cfg.meshRelayFraction,meshSpec.relayStrategy);
        failurePlan=generateFailurePlan(topo,N,pFail,failSpec,cfg);
        [treeSim,meshSim]=simulatePairedTrial(topo,N,lambda,cfg,comm,failurePlan,treeSpec,meshSpec);
        tv(tr,:)=[treeSim.PDR treeSim.Esucc treeSim.Enet_J treeSim.txEvents treeSim.rxEvents ...
            treeSim.meanHop treeSim.meanDepth treeSim.delivered treeSim.listenerCount];
        mv(tr,:)=[meshSim.PDR meshSim.Esucc meshSim.Enet_J meshSim.txEvents meshSim.rxEvents ...
            meshSim.meanHop meshSim.meanDepth meshSim.delivered meshSim.listenerCount];
    end
    treeOut=packMetric(tv); meshOut=packMetric(mv);
end

function out=packMetric(X)
    out=emptyMetric();
    out.PDR=meanNN(X(:,1)); out.PDRCI=ci95(X(:,1));
    out.Esucc=meanNN(X(:,2)); out.EsuccCI=ci95(X(:,2));
    out.Enet_mJ=1e3*meanNN(X(:,3)); out.EnetCI_mJ=1e3*ci95(X(:,3));
    out.txEvents=meanNN(X(:,4)); out.rxEvents=meanNN(X(:,5));
    out.meanHop=meanNN(X(:,6)); out.meanDepth=meanNN(X(:,7));
    out.delivered=meanNN(X(:,8)); out.listenerCount=meanNN(X(:,9));
end

function y=meanNN(x)
    x=x(~isnan(x)); if isempty(x), y=NaN; else, y=mean(x); end
end
function y=ci95(x)
    x=x(~isnan(x)); if numel(x)<=1, y=0; else, y=1.96*std(x,0)/sqrt(numel(x)); end
end

function topo=generateTopology(N,cfg)
    cn=N+1;
    pos=[cfg.areaSide*rand(N,2); cfg.areaSide/2 cfg.areaSide/2];
    dx=pos(:,1)-pos(:,1).'; dy=pos(:,2)-pos(:,2).';
    D=max(sqrt(dx.^2+dy.^2),cfg.d0);
    Z=cfg.sigmaShadow_dB*randn(N+1); Z=triu(Z,1); Z=Z+Z.'; Z(1:N+2:end)=0;
    Pr=cfg.txPower_dBm-cfg.PL0_dB-10*cfg.pathLossExp*log10(D/cfg.d0)+Z;
    Pr(1:N+2:end)=-Inf;
    feasible=Pr>=cfg.rxThreshold_dBm;
    z=(cfg.rxThreshold_dBm-Pr)/(sqrt(2)*cfg.sigmaFast_dB);
    pSingle=0.5*erfc(z); pSingle(1:N+2:end)=0;
    b0=cfg.batteryResidualRange(1)+diff(cfg.batteryResidualRange)*rand(N,1);
    topo.pos=pos; topo.D=D; topo.Pr=Pr; topo.feasible=feasible; topo.pSingle=pSingle;
    topo.batteryFraction=b0; topo.cn=cn; topo.N=N;
end

function parent=buildTree(topo,policy,N,available)
    cn=N+1;
    if nargin<4 || isempty(available), available=true(N,1); end
    connected=false(N+1,1); connected(cn)=true;
    hop=inf(N+1,1); hop(cn)=0; parent=zeros(N,1);
    for layer=1:N
        conIdx=find(connected); newN=[]; newP=[]; newH=[];
        for i=1:N
            if ~available(i) || connected(i), continue; end
            cand=conIdx(topo.feasible(i,conIdx));
            keep=true(size(cand));
            for q=1:numel(cand)
                if cand(q)<=N && ~available(cand(q)), keep(q)=false; end
            end
            cand=cand(keep);
            if isempty(cand), continue; end
            minHop=min(hop(cand)); pool=cand(hop(cand)==minHop);
            if any(pool==cn)
                p=cn;
            else
                switch lower(policy)
                    case 'minhop-battery'
                        score=topo.batteryFraction(pool);
                    case 'minhop-link'
                        score=arrayfun(@(j) topo.pSingle(i,j),pool);
                    case 'minhop-hybrid'
                        score=topo.batteryFraction(pool).*arrayfun(@(j) topo.pSingle(i,j),pool);
                    otherwise
                        error('Unknown Tree policy: %s',policy);
                end
                [~,ii]=max(score); p=pool(ii);
            end
            newN(end+1,1)=i; newP(end+1,1)=p; newH(end+1,1)=minHop+1; %#ok<AGROW>
        end
        if isempty(newN), break; end
        for q=1:numel(newN)
            i=newN(q); connected(i)=true; parent(i)=newP(q); hop(i)=newH(q);
        end
    end
end

function relayMask=chooseRelays(topo,N,rho,strategy)
    nRelay=max(1,ceil(rho*N));
    switch lower(strategy)
        case 'degree'
            score=sum(topo.feasible(1:N,:),2);
            [~,ord]=sort(score,'descend');
        case 'battery'
            [~,ord]=sort(topo.batteryFraction,'descend');
        case 'random'
            ord=randperm(N).';
        otherwise
            error('Unknown Mesh relay strategy: %s',strategy);
    end
    relayMask=false(N,1); relayMask(ord(1:nRelay))=true;
end

function plan=generateFailurePlan(topo,N,pFail,failSpec,cfg)
    plan.mode=failSpec.mode;
    switch lower(failSpec.mode)
        case 'transient'
            masks=rand(N,N)<pFail; % column s is mask for source packet s
            for s=1:N, masks(s,s)=false; end
            plan.masks=masks;
        case 'persistent-independent'
            plan.mask=rand(N,1)<pFail;
        case 'persistent-correlated'
            % Spatially correlated persistent unavailability is generated
            % from a Gaussian copula. IMPORTANT: use the TRUE Euclidean
            % geometry here, not topo.D. topo.D is clamped to d0 for the
            % path-loss model, including its diagonal, and therefore is not
            % a valid distance matrix for constructing a correlation kernel.
            P=topo.pos(1:N,:);
            dx=P(:,1)-P(:,1).';
            dy=P(:,2)-P(:,2).';
            Dcorr=sqrt(dx.^2+dy.^2);
            ell=max(cfg.failureCorrLength_m,eps);
            C=exp(-Dcorr/ell);
            C=(C+C')/2;
            C(1:N+1:end)=1;

            % Cholesky is fastest when the kernel is strictly positive
            % definite. Duplicate/nearly duplicate node coordinates can make
            % it only semidefinite numerically, so fall back to an eigenvalue
            % factorization with a tiny floor. Row normalization preserves
            % unit marginal variance, which is required by the Gaussian-copula
            % threshold below.
            [L,pchol]=chol(C,'lower');
            if pchol~=0
                [V,d]=eig(C,'vector');
                d=real(d); V=real(V);
                floorEig=max(1e-12,1e-10*max(abs(d)));
                d=max(d,floorEig);
                L=V*diag(sqrt(d));
                rowStd=sqrt(sum(L.^2,2));
                L=L./max(rowStd,eps);
            end

            z=L*randn(N,1);
            threshold=sqrt(2)*erfinv(2*pFail-1);
            plan.mask=z<threshold;
        otherwise
            error('Unknown failure mode: %s',failSpec.mode);
    end
end

function mask=getFailureMask(plan,src,N)
    switch lower(plan.mode)
        case 'transient'
            mask=plan.masks(:,src);
        otherwise
            mask=plan.mask;
    end
    mask=logical(mask); mask(src)=false; % condition reliability on operating source
    if numel(mask)~=N, error('Failure-mask length mismatch.'); end
end

function [tree,mesh]=simulatePairedTrial(topo,N,lambda,cfg,comm,plan,treeSpec,meshSpec)
    % Build nominal Tree paths and deterministic offered-load counts.
    parent=topo.treeParent;
    paths=cell(N,1); pathLen=nan(N,1);
    treeTxPotential=zeros(N,1);
    for s=1:N
        paths{s}=treePath(s,parent,N);
        if ~isempty(paths{s})
            pathLen(s)=size(paths{s},1);
            for h=1:size(paths{s},1)
                u=paths{s}(h,1); if u<=N, treeTxPotential(u)=treeTxPotential(u)+1; end
            end
        end
    end
    meshTxPotential=deterministicMeshRoundTx(topo.feasible,topo.relayMask,N,meshSpec.ttl,meshSpec.relayTransmissions);
    treeCol=collisionProfile(topo,treeTxPotential,N,lambda,cfg,comm.contention);
    meshCol=collisionProfile(topo,meshTxPotential,N,lambda,cfg,comm.contention);

    tree=simulateTree(topo,paths,N,lambda,cfg,treeCol,comm.channelCollisionCorrelation,plan,treeSpec);
    mesh=simulateMesh(topo,N,lambda,cfg,meshCol,comm.channelCollisionCorrelation,plan,meshSpec);
    tree.meanHop=meanNN(pathLen); tree.meanDepth=tree.meanHop;
end

function pCol=collisionProfile(topo,txRound,N,lambda,cfg,mode)
    % Link-specific collision-free probability. The tagged transmitter's own
    % event stream is excluded from the interferer load, since a node cannot
    % collide with itself. Rows are transmitters u; columns are receivers v.
    pCol=ones(N+1,N+1);
    switch lower(mode)
        case 'global'
            total=sum(txRound);
            for u=1:N
                G=lambda*max(total-txRound(u),0)*cfg.tPDU;
                pCol(u,:)=exp(-2*G);
            end
        case 'local'
            for u=1:N
                for v=1:N+1
                    audible=topo.feasible(1:N,v);
                    local=sum(txRound(audible));
                    if topo.feasible(u,v), local=max(local-txRound(u),0); end
                    Gv=lambda*local*cfg.tPDU;
                    pCol(u,v)=exp(-2*Gv);
                end
            end
        otherwise
            error('Unknown contention mode: %s',mode);
    end
    pCol=min(max(pCol,0),1);
end

function p=eventSuccess(pSingle,pCol,rho,K)
    pSingle=min(max(pSingle,0),1); pCol=min(max(pCol,0),1); rho=min(max(rho,0),1);
    % Independent collision state across K advertising copies.
    pind=1-(1-pSingle*pCol)^K;
    % Fully shared collision state: either the entire event overlaps or it does not.
    pshared=pCol*(1-(1-pSingle)^K);
    p=(1-rho)*pind+rho*pshared;
    p=min(max(p,0),1);
end

function out=simulateTree(topo,paths,N,lambda,cfg,pCol,rho,plan,treeSpec)
    cn=N+1; tx=zeros(N,1); rx=zeros(N,1); delivered=0; hopsDelivered=[];
    listener=false(N,1);
    parentNom=topo.treeParent;
    for i=1:N
        if parentNom(i)>0 && parentNom(i)<=N, listener(parentNom(i))=true; end
    end

    for src=1:N
        failed=getFailureMask(plan,src,N);
        path=paths{src};
        if treeSpec.reconstruct && ~strcmpi(plan.mode,'transient')
            avail=~failed; avail(src)=true;
            parentR=buildTree(topo,treeSpec.policy,N,avail);
            path=treePath(src,parentR,N);
        end
        if isempty(path), continue; end
        ok=true; usedHops=0;
        for h=1:size(path,1)
            u=path(h,1); v=path(h,2);
            if u<=N && failed(u), ok=false; break; end
            if v<=N && failed(v), ok=false; break; end
            hopOK=false;
            for attempt=1:(1+treeSpec.retries)
                if u<=N, tx(u)=tx(u)+1; end
                if v<=N, rx(v)=rx(v)+1; end
                pe=eventSuccess(topo.pSingle(u,v),pCol(u,v),rho,cfg.advChannels);
                if rand<=pe, hopOK=true; break; end
            end
            if ~hopOK, ok=false; break; end
            usedHops=usedHops+1;
        end
        if ok
            delivered=delivered+1; hopsDelivered(end+1,1)=usedHops; %#ok<AGROW>
        end
    end
    out=metricCounts(tx,rx,delivered,N,cfg);
    out.meanHop=meanNN(hopsDelivered); out.meanDepth=out.meanHop;
    out.listenerCount=sum(listener);
end

function out=simulateMesh(topo,N,lambda,cfg,pCol,rho,plan,meshSpec)
    cn=N+1; tx=zeros(N,1); rx=zeros(N,1); delivered=0; depthDelivered=[];
    for src=1:N
        failed=getFailureMask(plan,src,N);
        seen=false(N+1,1); seen(src)=true; frontier=src; firstDepth=NaN;
        for depth=1:meshSpec.ttl
            next=[];
            for uu=1:numel(frontier)
                u=frontier(uu);
                if u<=N && u~=src && failed(u), continue; end
                nRep=1; if u~=src, nRep=meshSpec.relayTransmissions; end
                recips=find(topo.feasible(u,:));
                for rep=1:nRep
                    if u<=N, tx(u)=tx(u)+1; end
                    for vv=1:numel(recips)
                        v=recips(vv);
                        if v<=N && ~topo.relayMask(v), continue; end
                        if v<=N && failed(v), continue; end
                        if v<=N, rx(v)=rx(v)+1; end
                        if ~seen(v)
                            pe=eventSuccess(topo.pSingle(u,v),pCol(u,v),rho,cfg.advChannels);
                            if rand<=pe
                                seen(v)=true;
                                if v==cn
                                    if isnan(firstDepth), firstDepth=depth; end
                                else
                                    next(end+1,1)=v; %#ok<AGROW>
                                end
                            end
                        end
                    end
                end
            end
            frontier=unique(next,'stable');
            if isempty(frontier) && (~isnan(firstDepth) || depth==meshSpec.ttl), break; end
        end
        if ~isnan(firstDepth)
            delivered=delivered+1; depthDelivered(end+1,1)=firstDepth; %#ok<AGROW>
        end
    end
    out=metricCounts(tx,rx,delivered,N,cfg);
    out.meanDepth=meanNN(depthDelivered); out.meanHop=out.meanDepth;
    out.listenerCount=sum(topo.relayMask);
end

function out=metricCounts(tx,rx,delivered,N,cfg)
    Edyn=sum(tx)*cfg.EtxEvent+sum(rx)*cfg.ErxEvent;
    out.PDR=delivered/N; out.Esucc=Edyn/max(delivered,1); out.Enet_J=Edyn;
    out.txEvents=sum(tx); out.rxEvents=sum(rx); out.delivered=delivered;
end

function path=treePath(src,parent,N)
    cn=N+1; path=zeros(0,2); u=src; visited=false(N+1,1);
    while u~=cn && u>0 && ~visited(u)
        visited(u)=true; v=parent(u);
        if v==0, path=zeros(0,2); return; end
        path(end+1,:)=[u v]; u=v; %#ok<AGROW>
    end
    if u~=cn, path=zeros(0,2); end
end

function txRound=deterministicMeshRoundTx(feasible,relayMask,N,ttl,relayTransmissions)
    cn=N+1; txRound=zeros(N,1);
    for src=1:N
        seen=false(N+1,1); seen(src)=true; frontier=src;
        for depth=1:ttl
            next=[];
            for uu=1:numel(frontier)
                u=frontier(uu); nRep=1; if u~=src, nRep=relayTransmissions; end
                if u<=N, txRound(u)=txRound(u)+nRep; end
                recips=find(feasible(u,:));
                for vv=1:numel(recips)
                    v=recips(vv);
                    if v==cn
                        seen(v)=true;
                    elseif relayMask(v) && ~seen(v)
                        seen(v)=true; next(end+1,1)=v; %#ok<AGROW>
                    end
                end
            end
            frontier=unique(next,'stable'); if isempty(frontier), break; end
        end
    end
end

function ch=classifyOne(t,m,Rmin)
    treeOK=t.PDR>=Rmin; meshOK=m.PDR>=Rmin;
    if treeOK && meshOK
        if t.Esucc<=m.Esucc, ch=1; else, ch=2; end
    elseif treeOK, ch=1;
    elseif meshOK, ch=2;
    else, ch=3;
    end
end

function [treeTrials,meshTrials]=collectDutyTrials(N,pFail,lambda,cfg,nTrials,seed,comm,fs,ts,ms)
    rng(seed,'twister');
    treeTrials.dynamicRound_J=zeros(nTrials,1); treeTrials.listenerCount=zeros(nTrials,1); treeTrials.delivered=zeros(nTrials,1);
    meshTrials.dynamicRound_J=zeros(nTrials,1); meshTrials.listenerCount=zeros(nTrials,1); meshTrials.delivered=zeros(nTrials,1);
    for tr=1:nTrials
        topo=generateTopology(N,cfg); topo.treeParent=buildTree(topo,ts.policy,N,[]);
        topo.relayMask=chooseRelays(topo,N,cfg.meshRelayFraction,ms.relayStrategy);
        plan=generateFailurePlan(topo,N,pFail,fs,cfg);
        [t,m]=simulatePairedTrial(topo,N,lambda,cfg,comm,plan,ts,ms);
        treeTrials.dynamicRound_J(tr)=t.Enet_J; treeTrials.listenerCount(tr)=t.listenerCount; treeTrials.delivered(tr)=t.delivered;
        meshTrials.dynamicRound_J(tr)=m.Enet_J; meshTrials.listenerCount(tr)=m.listenerCount; meshTrials.delivered(tr)=m.delivered;
    end
end

function rows=runGeometrySetting(settingID,sweepType,sweepValue,cfgG,pfVec,nTrials,seed,comm,fs,ts,ms)
    % First estimate topology hop statistics at p_f=0 using the same trial count.
    rng(seed,'twister'); hops=[]; direct=[];
    for tr=1:nTrials
        topo=generateTopology(cfgG.Ndefault,cfgG); parent=buildTree(topo,ts.policy,cfgG.Ndefault,[]);
        for s=1:cfgG.Ndefault
            p=treePath(s,parent,cfgG.Ndefault);
            if ~isempty(p)
                hops(end+1,1)=size(p,1); %#ok<AGROW>
                direct(end+1,1)=size(p,1)==1; %#ok<AGROW>
            end
        end
    end
    meanHop=meanNN(hops); p90=percentileSimple(hops,90); directFrac=meanNN(direct);
    localRows=cell(0,14); pdrTree=[];
    for ip=1:numel(pfVec)
        fprintf('  %s=%.3g, p_f=%.3f\n',sweepType,sweepValue,pfVec(ip));
        [t,m]=runPointEnhanced(cfgG.Ndefault,pfVec(ip),cfgG.lambdaDefault,cfgG,nTrials, ...
            seed+100+ip,comm,fs,ts,ms);
        pdrTree(end+1)=t.PDR; %#ok<AGROW>
        localRows=[localRows; {settingID,sweepType,sweepValue,pfVec(ip),t.PDR,t.PDRCI,m.PDR,m.PDRCI, ... %#ok<AGROW>
            1e6*t.Esucc,1e6*m.Esucc,meanHop,p90,directFrac,NaN}];
    end
    pCross=thresholdCrossing(pfVec,pdrTree,cfgG.reliabilityTarget);
    for r=1:size(localRows,1), localRows{r,14}=pCross; end
    rows=localRows;
end

function p=percentileSimple(x,pct)
    x=sort(x(~isnan(x))); if isempty(x), p=NaN; return; end
    idx=1+(numel(x)-1)*pct/100; lo=floor(idx); hi=ceil(idx);
    if lo==hi, p=x(lo); else, p=x(lo)+(idx-lo)*(x(hi)-x(lo)); end
end

function pc=thresholdCrossing(p,y,target)
    [p,ord]=sort(p); y=y(ord); pc=NaN;
    for k=1:numel(p)-1
        if (y(k)-target)*(y(k+1)-target)<=0 && y(k)~=y(k+1)
            pc=p(k)+(target-y(k))*(p(k+1)-p(k))/(y(k+1)-y(k)); return;
        end
    end
end

%% ----------------------------- PLOTTING ---------------------------------
function plotTask1(T,outDir,saveFig)
    models=unique(T.Model,'stable');
    f=figure('Color','w','Position',[100 100 900 360]);
    tiledlayout(1,2,'Padding','compact','TileSpacing','compact');
    nexttile; hold on;
    for i=1:numel(models)
        A=T(T.Model==models(i),:); [x,o]=sort(A.lambda); A=A(o,:);
        plot(x,A.TreePDR,'-o','LineWidth',1.1,'DisplayName',char(models(i)));
    end
    set(gca,'XScale','log'); grid on; box on; ylim([0 1.02]); xlabel('\lambda (packet/s/node)'); ylabel('Tree PDR'); legend('Location','southwest');
    nexttile; hold on;
    for i=1:numel(models)
        A=T(T.Model==models(i),:); [x,o]=sort(A.lambda); A=A(o,:);
        plot(x,A.MeshPDR,'-o','LineWidth',1.1,'DisplayName',char(models(i)));
    end
    set(gca,'XScale','log'); grid on; box on; ylim([0 1.02]); xlabel('\lambda (packet/s/node)'); ylabel('Mesh PDR'); legend('Location','southwest');
    styleFigure(f); safeExport(f,fullfile(outDir,'task1_communication_model_sensitivity'),saveFig);
end

function plotTask2(T,outDir,saveFig)
    modes=unique(T.FailureMode,'stable');
    f=figure('Color','w','Position',[100 100 900 360]); tiledlayout(1,2,'Padding','compact','TileSpacing','compact');
    nexttile; hold on;
    for i=1:numel(modes), A=T(T.FailureMode==modes(i),:); errorbar(A.pFail,A.TreePDR,A.TreePDR_CI95,'-o','DisplayName',char(modes(i))); end
    grid on; box on; ylim([0 1.02]); xlabel('p_f'); ylabel('Tree PDR'); legend('Location','southwest');
    nexttile; hold on;
    for i=1:numel(modes), A=T(T.FailureMode==modes(i),:); errorbar(A.pFail,A.MeshPDR,A.MeshPDR_CI95,'-o','DisplayName',char(modes(i))); end
    grid on; box on; ylim([0 1.02]); xlabel('p_f'); ylabel('Mesh PDR'); legend('Location','southwest');
    styleFigure(f); safeExport(f,fullfile(outDir,'task2_failure_model_sensitivity'),saveFig);
end

function plotTask3(T,outDir,saveFig,Rmin)
    names=unique(T.TreeConfiguration,'stable'); f=figure('Color','w'); hold on;
    for i=1:numel(names), A=T(T.TreeConfiguration==names(i),:); errorbar(A.pFail,A.TreePDR,A.TreePDR_CI95,'-o','DisplayName',char(names(i))); end
    yline(Rmin,'--','R_{min}'); grid on; box on; ylim([0 1.02]); xlabel('Persistent unavailability probability, p_f'); ylabel('Tree PDR'); legend('Location','southwest');
    styleFigure(f); safeExport(f,fullfile(outDir,'task3_tree_retry_reconstruction'),saveFig);
end

function plotTask4(T,outDir,saveFig)
    dt=unique(T.TreeReceiveDuty); dm=unique(T.MeshReceiveDuty); Z=nan(numel(dt),numel(dm));
    for i=1:numel(dt), for j=1:numel(dm), r=T.TreeReceiveDuty==dt(i)&T.MeshReceiveDuty==dm(j); Z(i,j)=T.MeshToTreeEnergyRatio(r); end, end
    f=figure('Color','w'); imagesc(dm,dt,Z); set(gca,'YDir','normal'); colorbar; xlabel('Mesh relay receive duty factor'); ylabel('Tree-parent receive duty factor'); title('Mesh/Tree energy-per-delivered-packet ratio');
    styleFigure(f); safeExport(f,fullfile(outDir,'task4_receiver_duty_cycle_sensitivity'),saveFig);
end

function plotTask5(choice,lambdaVec,pfVec,outDir,saveFig)
    f=figure('Color','w'); imagesc(pfVec,1:numel(lambdaVec),choice); set(gca,'YDir','normal','YTick',1:numel(lambdaVec),'YTickLabel',string(lambdaVec));
    colormap(parula(3)); cb=colorbar; cb.Ticks=[1 2 3]; cb.TickLabels={'Tree','Mesh','Neither'};
    xlabel('p_f'); ylabel('\lambda (packet/s/node)'); title('Reliability-constrained architecture selection');
    styleFigure(f); safeExport(f,fullfile(outDir,'task5_load_failure_crossover'),saveFig);
end

function plotTask6(T,outDir,saveFig,Rmin)
    settings=unique(T.SettingID,'stable'); f=figure('Color','w','Position',[100 100 900 360]); tiledlayout(1,2,'Padding','compact','TileSpacing','compact');
    nexttile; hold on;
    for i=1:numel(settings)
        A=T(T.SettingID==settings(i),:); plot(A.pFail,A.TreePDR,'-o','DisplayName',sprintf('%s=%.3g',A.SweepType{1},A.SweepValue(1)));
    end
    yline(Rmin,'--','R_{min}'); grid on; box on; xlabel('p_f'); ylabel('Tree PDR'); legend('Location','southwest');
    nexttile; hold on;
    vals=[]; labels={};
    for i=1:numel(settings), A=T(T.SettingID==settings(i),:); vals(end+1)=A.TreeCrossingEstimate(1); labels{end+1}=sprintf('%s=%.3g',A.SweepType{1},A.SweepValue(1)); end %#ok<AGROW>
    bar(vals); set(gca,'XTick',1:numel(vals),'XTickLabel',labels,'XTickLabelRotation',35); ylabel('Estimated p_f crossing'); grid on; box on;
    styleFigure(f); safeExport(f,fullfile(outDir,'task6_geometry_hop_sensitivity'),saveFig);
end

function plotTask7(Ttree,Trelay,Tttl,Trep,outDir,saveFig)
    f=figure('Color','w','Position',[100 100 1000 700]); tiledlayout(2,2,'Padding','compact','TileSpacing','compact');
    nexttile; bar(Ttree.TreePDR); set(gca,'XTick',1:height(Ttree),'XTickLabel',Ttree.Policy,'XTickLabelRotation',25); ylabel('Tree PDR'); grid on; box on;
    nexttile; bar(Trelay.MeshPDR); set(gca,'XTick',1:height(Trelay),'XTickLabel',Trelay.Strategy); ylabel('Mesh PDR'); grid on; box on;
    nexttile; yyaxis left; plot(Tttl.TTL,Tttl.MeshPDR,'-o'); ylabel('Mesh PDR'); yyaxis right; plot(Tttl.TTL,Tttl.MeshEnergy_uJ,'-s'); ylabel('Energy (\muJ)'); xlabel('TTL'); grid on;
    nexttile; yyaxis left; plot(Trep.RelayTransmissions,Trep.MeshPDR,'-o'); ylabel('Mesh PDR'); yyaxis right; plot(Trep.RelayTransmissions,Trep.MeshEnergy_uJ,'-s'); ylabel('Energy (\muJ)'); xlabel('Relay transmissions/message'); grid on;
    styleFigure(f); safeExport(f,fullfile(outDir,'task7_policy_sensitivity'),saveFig);
end

function styleFigure(f)
    axs=findall(f,'Type','axes'); for k=1:numel(axs), set(axs(k),'FontName','Times New Roman','FontSize',9); end
end

function safeExport(fig,base,saveFig)
    try, print(fig,[base '.png'],'-dpng','-r300'); catch ME, warning('PNG export failed: %s',ME.message); end
    try, print(fig,[base '.pdf'],'-dpdf','-painters'); catch ME, warning('PDF export failed: %s',ME.message); end
    if saveFig
        try, savefig(fig,[base '.fig']); catch ME, warning('FIG save failed: %s',ME.message); end
    end
    close(fig);
end

function writeConfig(cfg,file)
    fid=fopen(file,'w'); if fid<0, return; end
    fields=fieldnames(cfg);
    for i=1:numel(fields)
        v=cfg.(fields{i});
        if isnumeric(v) && isscalar(v), fprintf(fid,'%s=%g\n',fields{i},v);
        elseif ischar(v), fprintf(fid,'%s=%s\n',fields{i},v);
        end
    end
    fclose(fid);
end
