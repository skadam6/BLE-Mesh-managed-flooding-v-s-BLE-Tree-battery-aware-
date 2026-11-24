%% BLE Tree vs Managed-Flooding Mesh Validation Study
% Standalone MATLAB R2025b script; no specialized toolbox required.
%
% PURPOSE: generate the validation datasets used in the paper:
% (1) audit the large Tree-vs-Mesh energy gap and expose TX/RX components;
% (2) sweep the Mesh relay fraction;
% (3) recompute crossover maps for R_min = 0.90, 0.95, 0.99 without rerunning
%     Monte Carlo when the existing crossover CSVs are available;
% (4) run high-trial targeted Monte Carlo near the Tree reliability boundary;
% (5) use one physical node-failure realization per trial, shared by Tree and Mesh.
%
% OUTPUT: CSV + PDF + PNG + FIG files under ./validation_results/
%
% HOW TO RUN:
%   1) Place this file in the same folder that contains the existing ./results/
%      directory from ble_tree_mesh_master.m.
%   2) For a genuinely fast code/path check, set quickMode = true.
%      Quick mode reduces BOTH trial counts and sweep points and skips .fig.
%   3) For paper-quality validation, set quickMode = false and Run.
%
% IMPORTANT: This script does NOT overwrite the original ./results/ folder.

clc; close all;

quickMode = false;                  % <-- true = syntax/path sanity check only
outDir = 'validation_results';
if ~exist(outDir,'dir'), mkdir(outDir); end

cfg = defaultConfig();
if quickMode
    % Intentionally tiny: this mode is ONLY to verify that the simulation runs.
    nAudit    = 1;
    nRelay    = 1;
    nBoundary = 2;
else
    nAudit    = 150;
    nRelay    = 120;
    nBoundary = 300;
end

% IMPORTANT: This v3 script is simulation/CSV ONLY. It deliberately creates
% no MATLAB figures and calls neither exportgraphics nor savefig. After the
% Monte Carlo run finishes, run ble_validation_make_plots.m to create PDF,
% PNG, and optional FIG files from the saved CSVs without rerunning simulation.

fprintf('BLE Tree-vs-Mesh validation patch v3 (CSV-only simulation)\n');
fprintf('quickMode = %d\n',quickMode);
fprintf('Trials: audit=%d, relay=%d, boundary=%d\n',nAudit,nRelay,nBoundary);
fprintf('Shared physical failure realization is ENABLED for Tree and Mesh.\n\n');

%% ========================================================================
% TASK 1. Energy-gap audit
% ========================================================================
% Target only representative network sizes. The audit reports TX/RX event
% counts and their separate dynamic-energy contributions, which explains why
% managed flooding becomes expensive as network density grows.
if quickMode
    Naudit = 80;
else
    Naudit = [40 80 120 160 200];
end
auditTree = repmat(emptyMetric(),numel(Naudit),1);
auditMesh = repmat(emptyMetric(),numel(Naudit),1);

for k = 1:numel(Naudit)
    N = Naudit(k);
    fprintf('Task 1/5 - energy audit: N=%d\n',N);
    [auditTree(k),auditMesh(k)] = runPoint(N,cfg.pFailDefault,cfg.lambdaDefault, ...
        cfg,nAudit,cfg.seed + 10000 + N);
end

Taudit = table(Naudit(:), ...
    [auditTree.PDR].',[auditMesh.PDR].', ...
    1e6*[auditTree.Esucc].',1e6*[auditMesh.Esucc].', ...
    1e6*[auditTree.EtxRound_J].',1e6*[auditMesh.EtxRound_J].', ...
    1e6*[auditTree.ErxRound_J].',1e6*[auditMesh.ErxRound_J].', ...
    [auditTree.txEvents].',[auditMesh.txEvents].', ...
    [auditTree.rxEvents].',[auditMesh.rxEvents].', ...
    [auditMesh.Esucc].'./[auditTree.Esucc].', ...
    'VariableNames',{'N','TreePDR','MeshPDR','TreeEnergy_uJ','MeshEnergy_uJ', ...
    'TreeTxEnergyPerRound_uJ','MeshTxEnergyPerRound_uJ', ...
    'TreeRxEnergyPerRound_uJ','MeshRxEnergyPerRound_uJ', ...
    'TreeTxEvents','MeshTxEvents','TreeRxEvents','MeshRxEvents','MeshToTreeEnergyRatio'});
writetable(Taudit,fullfile(outDir,'task1_energy_audit.csv'));

% Figures are generated later by ble_validation_make_plots.m.

%% ========================================================================
% TASK 2. Mesh relay-fraction sensitivity
% ========================================================================
% Tree is recomputed for the same paired topology/failure process for each
% point. Only the Mesh relay fraction changes.
if quickMode
    rhoVec = [0.20 0.40];
    pfRelay = [0 0.50];
else
    rhoVec = [0.20 0.30 0.40 0.50 0.60];
    pfRelay = [0 0.10 0.20 0.30 0.40 0.50];
end
rows = [];

for ir = 1:numel(rhoVec)
    cfgR = cfg;
    cfgR.meshRelayFraction = rhoVec(ir);
    for ip = 1:numel(pfRelay)
        pf = pfRelay(ip);
        fprintf('Task 2/5 - relay sensitivity: rho=%.2f, p_f=%.2f\n',rhoVec(ir),pf);
        [t,m] = runPoint(cfg.Ndefault,pf,cfg.lambdaDefault,cfgR,nRelay, ...
            cfg.seed + 20000 + 10*ip);
        rows = [rows; rhoVec(ir) pf t.PDR t.PDRCI m.PDR m.PDRCI ... %#ok<AGROW>
            1e6*t.Esucc 1e6*t.EsuccCI 1e6*m.Esucc 1e6*m.EsuccCI ...
            1e3*t.delay 1e3*m.delay t.overhead m.overhead];
    end
end

Trelay = array2table(rows,'VariableNames',{'RelayFraction','pFail', ...
    'TreePDR','TreePDR_CI95','MeshPDR','MeshPDR_CI95', ...
    'TreeEnergy_uJ','TreeEnergy_CI95_uJ','MeshEnergy_uJ','MeshEnergy_CI95_uJ', ...
    'TreeDelay_ms','MeshDelay_ms','TreeOverhead','MeshOverhead'});
writetable(Trelay,fullfile(outDir,'task2_relay_fraction_sensitivity.csv'));

% Figures are generated later by ble_validation_make_plots.m.

%% ========================================================================
% TASK 3. Reliability-target sensitivity WITHOUT rerunning Monte Carlo
% ========================================================================
% Reuse the existing crossover matrices generated by the master script.
% This is exact for changing R_min because R_min only classifies already
% computed PDR/energy values; it does not change the packet simulations.
Rtargets = [0.90 0.95 0.99];
baseDir = 'results';
required = {fullfile(baseDir,'crossover_tree_pdr.csv'), ...
            fullfile(baseDir,'crossover_mesh_pdr.csv'), ...
            fullfile(baseDir,'crossover_tree_energy_uJ.csv'), ...
            fullfile(baseDir,'crossover_mesh_energy_uJ.csv')};

if all(cellfun(@(f) exist(f,'file')==2,required))
    treeP = readmatrix(required{1});
    meshP = readmatrix(required{2});
    treeE = readmatrix(required{3});
    meshE = readmatrix(required{4});

    % Current master-script axes. Verify against matrix dimensions.
    Nmap = 10:10:200;
    pfMap = 0:0.05:0.50;
    if ~isequal(size(treeP),[numel(Nmap) numel(pfMap)])
        error(['Existing crossover CSV dimensions do not match N=10:10:200 and ' ...
               'p_f=0:0.05:0.50. Update Nmap/pfMap in Task 3.']);
    end

    summaryRows = [];
    for r = 1:numel(Rtargets)
        Rmin = Rtargets(r);
        choice = classifyArchitecture(treeP,meshP,treeE,meshE,Rmin);
        writematrix(choice,fullfile(outDir,sprintf('task3_choice_Rmin_%0.2f.csv',Rmin)));

        nTree = sum(choice(:)==1); nMesh = sum(choice(:)==2); nNeither = sum(choice(:)==3);
        summaryRows = [summaryRows; Rmin nTree nMesh nNeither]; %#ok<AGROW>
        % Figure generation deferred to ble_validation_make_plots.m.
    end
    Ttarget = array2table(summaryRows,'VariableNames', ...
        {'Rmin','NumTreeCells','NumMeshCells','NumNeitherCells'});
    writetable(Ttarget,fullfile(outDir,'task3_reliability_target_summary.csv'));
else
    warning(['Task 3 skipped because the existing ./results/crossover_*.csv files ' ...
             'were not found. Copy the original results folder beside this script and rerun.']);
end

%% ========================================================================
% TASK 4. Targeted high-trial Monte Carlo near the reliability boundary
% ========================================================================
% The old coarse failure sweep suggested the Tree crosses R_min around
% p_f ~= 0.10--0.15. We therefore spend trials only around that boundary.
if quickMode
    Nboundary = 80;
    pfBoundary = [0.10 0.15];
else
    Nboundary = [40 80 120 160 200];
    pfBoundary = [0.08 0.10 0.12 0.14 0.16 0.18 0.20];
end
bRows = [];

for iN = 1:numel(Nboundary)
    N = Nboundary(iN);
    for ip = 1:numel(pfBoundary)
        pf = pfBoundary(ip);
        fprintf('Task 4/5 - boundary refinement: N=%d, p_f=%.2f\n',N,pf);
        [t,m] = runPoint(N,pf,cfg.lambdaDefault,cfg,nBoundary, ...
            cfg.seed + 30000 + 100*N + ip);
        bRows = [bRows; N pf t.PDR t.PDRCI m.PDR m.PDRCI ... %#ok<AGROW>
            1e6*t.Esucc 1e6*m.Esucc];
    end
end

Tboundary = array2table(bRows,'VariableNames',{'N','pFail', ...
    'TreePDR','TreePDR_CI95','MeshPDR','MeshPDR_CI95','TreeEnergy_uJ','MeshEnergy_uJ'});
writetable(Tboundary,fullfile(outDir,'task4_boundary_refinement.csv'));

% Estimate Tree's p_f crossing at PDR = R_min by local linear interpolation.
crossRows = nan(numel(Nboundary),4);
for iN = 1:numel(Nboundary)
    N = Nboundary(iN);
    idx = Tboundary.N==N;
    p = Tboundary.pFail(idx);
    y = Tboundary.TreePDR(idx);
    ci = Tboundary.TreePDR_CI95(idx);
    [p,ord]=sort(p); y=y(ord); ci=ci(ord);
    pCross = interpolateThresholdCrossing(p,y,cfg.reliabilityTarget);
    crossRows(iN,:) = [N pCross min(y) max(ci)];
end
Tcross = array2table(crossRows,'VariableNames', ...
    {'N','EstimatedTreeCrossing_pFail','MinTreePDRInWindow','MaxTreePDR_CI95'});
writetable(Tcross,fullfile(outDir,'task4_estimated_tree_crossing.csv'));

% Figure generation deferred to ble_validation_make_plots.m.

%% ========================================================================
% TASK 5. Shared-failure-realization check
% ========================================================================
% Task 5 is already active in ALL simulations above: runPoint() draws exactly
% one physical failed-node mask per Monte Carlo trial and supplies that same
% mask to Tree and Mesh. Here we save a compact paired-comparison table at the
% default operating point and at the high-failure point p_f=0.15.
pfPair = [cfg.pFailDefault 0.15];
pairRows = [];
for k = 1:numel(pfPair)
    [t,m] = runPoint(cfg.Ndefault,pfPair(k),cfg.lambdaDefault,cfg,nBoundary, ...
        cfg.seed + 40000 + k);
    pairRows = [pairRows; pfPair(k) t.PDR t.PDRCI m.PDR m.PDRCI ... %#ok<AGROW>
        1e6*t.Esucc 1e6*t.EsuccCI 1e6*m.Esucc 1e6*m.EsuccCI];
end
Tpair = array2table(pairRows,'VariableNames',{'pFail','TreePDR','TreePDR_CI95', ...
    'MeshPDR','MeshPDR_CI95','TreeEnergy_uJ','TreeEnergy_CI95_uJ', ...
    'MeshEnergy_uJ','MeshEnergy_CI95_uJ'});
writetable(Tpair,fullfile(outDir,'task5_shared_failure_check.csv'));

%% Save configuration used
fid=fopen(fullfile(outDir,'validation_config.txt'),'w');
fprintf(fid,'seed=%d\n',cfg.seed);
fprintf(fid,'areaSide_m=%.6g\n',cfg.areaSide);
fprintf(fid,'txPower_dBm=%.6g\n',cfg.txPower_dBm);
fprintf(fid,'PL0_dB=%.6g\n',cfg.PL0_dB);
fprintf(fid,'pathLossExp=%.6g\n',cfg.pathLossExp);
fprintf(fid,'sigmaShadow_dB=%.6g\n',cfg.sigmaShadow_dB);
fprintf(fid,'sigmaFast_dB=%.6g\n',cfg.sigmaFast_dB);
fprintf(fid,'rxThreshold_dBm=%.6g\n',cfg.rxThreshold_dBm);
fprintf(fid,'airBytes=%d\n',cfg.airBytes);
fprintf(fid,'phyRate_bps=%.6g\n',cfg.phyRate);
fprintf(fid,'advChannels=%d\n',cfg.advChannels);
fprintf(fid,'V=%.6g\n',cfg.V);
fprintf(fid,'I_tx_A=%.6g\n',cfg.I_tx);
fprintf(fid,'I_rx_A=%.6g\n',cfg.I_rx);
fprintf(fid,'I_sleep_A=%.6g\n',cfg.I_sleep);
fprintf(fid,'battery_mAh=%.6g\n',cfg.battery_mAh);
fprintf(fid,'meshRelayFraction=%.6g\n',cfg.meshRelayFraction);
fprintf(fid,'meshTTL=%d\n',cfg.meshTTL);
fprintf(fid,'Ndefault=%d\n',cfg.Ndefault);
fprintf(fid,'lambdaDefault=%.6g\n',cfg.lambdaDefault);
fprintf(fid,'pFailDefault=%.6g\n',cfg.pFailDefault);
fprintf(fid,'reliabilityTarget=%.6g\n',cfg.reliabilityTarget);
fprintf(fid,'nAudit=%d\n',nAudit);
fprintf(fid,'nRelay=%d\n',nRelay);
fprintf(fid,'nBoundary=%d\n',nBoundary);
fprintf(fid,'quickMode=%d\n',quickMode);
fprintf(fid,'figureExport=deferred_to_ble_validation_make_plots.m\n');
fclose(fid);

fprintf('\nValidation study complete. Upload the entire "%s" folder for analysis.\n',outDir);
fprintf('No figures were created by design. Run ble_validation_make_plots.m afterward.\n');
fprintf('Most important files: task1_energy_audit.csv, task2_relay_fraction_sensitivity.csv,\n');
fprintf('task3_reliability_target_summary.csv, task4_boundary_refinement.csv,\n');
fprintf('task4_estimated_tree_crossing.csv, and task5_shared_failure_check.csv.\n');

%% ========================= Local functions ==============================
function cfg = defaultConfig()
    cfg.seed = 17;

    % Common deployment/channel model
    cfg.areaSide = 100;
    cfg.txPower_dBm = 0;
    cfg.PL0_dB = 40;
    cfg.d0 = 1;
    cfg.pathLossExp = 3.0;
    cfg.sigmaShadow_dB = 3.0;
    cfg.sigmaFast_dB = 2.5;
    cfg.rxThreshold_dBm = -90;

    % Packet/radio energy abstraction
    cfg.airBytes = 47;
    cfg.phyRate = 1e6;
    cfg.advChannels = 3;
    cfg.V = 3.0;
    cfg.I_tx = 4.8e-3;
    cfg.I_rx = 4.6e-3;
    cfg.I_sleep = 2e-6;
    cfg.battery_mAh = 235;
    cfg.batteryResidualRange = [0.85 1.00];
    cfg.energyWindow_s = 3600;
    cfg.tPDU = 8*cfg.airBytes/cfg.phyRate;
    cfg.EtxEvent = cfg.advChannels*cfg.V*cfg.I_tx*cfg.tPDU;
    cfg.ErxEvent = cfg.V*cfg.I_rx*cfg.tPDU;

    % Tree/Mesh forwarding settings
    cfg.treeHopDelay = 0.010;
    cfg.meshHopDelay = 0.015;
    cfg.meshRelayFraction = 0.40;
    cfg.meshTTL = 6;

    % Traffic/failure defaults
    cfg.Ndefault = 80;
    cfg.lambdaDefault = 0.10;
    cfg.pFailDefault = 0.05;
    cfg.reliabilityTarget = 0.95;
end

function m = emptyMetric()
    m = struct('PDR',NaN,'PDRCI',NaN,'Esucc',NaN,'EsuccCI',NaN, ...
        'delay',NaN,'delayCI',NaN,'overhead',NaN,'overheadCI',NaN, ...
        'FNDdays',NaN,'FNDdaysCI',NaN,'L10days',NaN,'L10daysCI',NaN, ...
        'collisionFactor',NaN,'meanLogicalTx',NaN,'Ewindow_J',NaN, ...
        'txEvents',NaN,'rxEvents',NaN,'EtxRound_J',NaN,'ErxRound_J',NaN);
end

function [treeOut,meshOut] = runPoint(N,pFail,lambda,cfg,nTrials,seed)
    rng(seed,'twister');
    treeVals = nan(nTrials,13);
    meshVals = nan(nTrials,13);
    for tr = 1:nTrials
        topo = generateTopology(N,cfg);
        % One PHYSICAL failed-node realization per trial, shared by Tree/Mesh.
        failedPhysical = rand(N,1) < pFail;
        [treeVals(tr,:),meshVals(tr,:)] = simulateTrial(topo,N,lambda,cfg,failedPhysical);
    end
    treeOut = packMetric(treeVals);
    meshOut = packMetric(meshVals);
end

function out = packMetric(X)
    % Columns: PDR, Esucc, delay, overhead, FND, L10, pCollision, meanTx,
    % Ewindow, txEvents, rxEvents, EtxRound, ErxRound.
    out = emptyMetric();
    out.PDR = meanNoNaN(X(:,1));            out.PDRCI = ci95(X(:,1));
    out.Esucc = meanNoNaN(X(:,2));          out.EsuccCI = ci95(X(:,2));
    out.delay = meanNoNaN(X(:,3));          out.delayCI = ci95(X(:,3));
    out.overhead = meanNoNaN(X(:,4));       out.overheadCI = ci95(X(:,4));
    out.FNDdays = meanNoNaN(X(:,5));        out.FNDdaysCI = ci95(X(:,5));
    out.L10days = meanNoNaN(X(:,6));        out.L10daysCI = ci95(X(:,6));
    out.collisionFactor = meanNoNaN(X(:,7));
    out.meanLogicalTx = meanNoNaN(X(:,8));
    out.Ewindow_J = meanNoNaN(X(:,9));
    out.txEvents = meanNoNaN(X(:,10));
    out.rxEvents = meanNoNaN(X(:,11));
    out.EtxRound_J = meanNoNaN(X(:,12));
    out.ErxRound_J = meanNoNaN(X(:,13));
end

function y = meanNoNaN(x)
    x=x(~isnan(x));
    if isempty(x), y=NaN; else, y=mean(x); end
end

function y = ci95(x)
    x=x(~isnan(x));
    if numel(x)<=1, y=0; else, y=1.96*std(x,0)/sqrt(numel(x)); end
end

function topo = generateTopology(N,cfg)
    cn=N+1;
    pos=[cfg.areaSide*rand(N,2); cfg.areaSide/2,cfg.areaSide/2];
    dx=pos(:,1)-pos(:,1).'; dy=pos(:,2)-pos(:,2).';
    D=max(sqrt(dx.^2+dy.^2),cfg.d0);

    Z=cfg.sigmaShadow_dB*randn(N+1);
    Z=triu(Z,1); Z=Z+Z.'; Z(1:N+2:end)=0;
    Pr=cfg.txPower_dBm-cfg.PL0_dB-10*cfg.pathLossExp*log10(D/cfg.d0)+Z;
    Pr(1:N+2:end)=-Inf;

    feasible=Pr>=cfg.rxThreshold_dBm;
    z=(cfg.rxThreshold_dBm-Pr)/(sqrt(2)*cfg.sigmaFast_dB);
    pSingle=0.5*erfc(z); pSingle(1:N+2:end)=0;

    b0=cfg.batteryResidualRange(1)+diff(cfg.batteryResidualRange)*rand(N,1);
    [parent,hop]=buildBatteryAwareTree(feasible,b0,N);

    degree=sum(feasible(1:N,:),2);
    nRelay=max(1,ceil(cfg.meshRelayFraction*N));
    [~,order]=sort(degree,'descend');
    relayMask=false(N,1); relayMask(order(1:nRelay))=true;

    topo.pos=pos; topo.feasible=feasible; topo.pSingle=pSingle;
    topo.parent=parent; topo.hop=hop; topo.relayMask=relayMask;
    topo.batteryFraction=b0; topo.cn=cn;
end

function [parent,hopSensor] = buildBatteryAwareTree(feasible,batteryFraction,N)
    cn=N+1;
    marked=false(N+1,1); marked(cn)=true;
    hop=inf(N+1,1); hop(cn)=0;
    parent=zeros(N,1);
    for layer=1:N
        markedIdx=find(marked);
        newNodes=[]; newParents=[]; newHops=[];
        for i=1:N
            if marked(i), continue; end
            cand=markedIdx(feasible(i,markedIdx));
            if isempty(cand), continue; end
            minHop=min(hop(cand)); pool=cand(hop(cand)==minHop);
            if any(pool==cn)
                p=cn;
            else
                [~,ii]=max(batteryFraction(pool)); p=pool(ii);
            end
            newNodes(end+1,1)=i; newParents(end+1,1)=p; newHops(end+1,1)=minHop+1; %#ok<AGROW>
        end
        if isempty(newNodes), break; end
        for q=1:numel(newNodes)
            i=newNodes(q); marked(i)=true; parent(i)=newParents(q); hop(i)=newHops(q);
        end
    end
    hopSensor=hop(1:N);
end

function path = treePath(src,parent,N)
    cn=N+1; path=zeros(0,2); u=src; visited=false(N+1,1);
    while u~=cn && u>0 && ~visited(u)
        visited(u)=true; v=parent(u);
        if v==0, path=zeros(0,2); return; end
        path(end+1,:)=[u v]; %#ok<AGROW>
        u=v;
    end
    if u~=cn, path=zeros(0,2); end
end

function nTx = deterministicMeshTx(feasible,relayMask,src,N,ttl)
    cn=N+1; seen=false(N+1,1); seen(src)=true; frontier=src; nTx=0;
    for depth=1:ttl
        next=[];
        for uu=1:numel(frontier)
            u=frontier(uu); nTx=nTx+1;
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
        frontier=unique(next,'stable');
        if isempty(frontier), break; end
    end
end

function [treeVec,meshVec] = simulateTrial(topo,N,lambda,cfg,failedPhysical)
    paths=cell(N,1); pathLens=nan(N,1); meshTx0=zeros(N,1);
    for s=1:N
        paths{s}=treePath(s,topo.parent,N);
        if ~isempty(paths{s}), pathLens(s)=size(paths{s},1); end
        meshTx0(s)=deterministicMeshTx(topo.feasible,topo.relayMask,s,N,cfg.meshTTL);
    end
    meanTreeTx=meanNoNaN(pathLens); if isnan(meanTreeTx), meanTreeTx=1; end
    meanMeshTx=mean(meshTx0);

    Gtree=lambda*N*meanTreeTx*cfg.tPDU;
    Gmesh=lambda*N*meanMeshTx*cfg.tPDU;
    pColTree=exp(-2*Gtree); pColMesh=exp(-2*Gmesh);

    tree=simulateTreePackets(topo,paths,N,lambda,pColTree,cfg,failedPhysical);
    mesh=simulateMeshPackets(topo,N,lambda,pColMesh,cfg,failedPhysical);

    treeVec=[tree.PDR tree.Esucc tree.delay tree.overhead tree.FND tree.L10 ...
        pColTree meanTreeTx tree.Ewindow_J tree.txEvents tree.rxEvents ...
        tree.EtxRound_J tree.ErxRound_J];
    meshVec=[mesh.PDR mesh.Esucc mesh.delay mesh.overhead mesh.FND mesh.L10 ...
        pColMesh meanMeshTx mesh.Ewindow_J mesh.txEvents mesh.rxEvents ...
        mesh.EtxRound_J mesh.ErxRound_J];
end

function out = simulateTreePackets(topo,paths,N,lambda,pCollision,cfg,failedPhysical)
    txCount=zeros(N,1); rxCount=zeros(N,1);
    delivered=0; delayList=[]; relayTx=0;
    for src=1:N
        failed=failedPhysical;
        failed(src)=false; % condition reliability on an operating source
        path=paths{src}; if isempty(path), continue; end
        ok=true; hopsAttempted=0;
        for h=1:size(path,1)
            u=path(h,1); v=path(h,2);
            if u~=src && failed(u), ok=false; break; end
            hopsAttempted=hopsAttempted+1; txCount(u)=txCount(u)+1;
            if v<=N
                if failed(v), ok=false; break; end
                rxCount(v)=rxCount(v)+1;
            end
            q=min(max(topo.pSingle(u,v)*pCollision,0),1);
            pEvent=1-(1-q)^cfg.advChannels;
            if rand>pEvent, ok=false; break; end
        end
        relayTx=relayTx+max(0,hopsAttempted-1);
        if ok
            delivered=delivered+1;
            delayList(end+1,1)=hopsAttempted*cfg.treeHopDelay; %#ok<AGROW>
        end
    end
    out=metricFromCounts(txCount,rxCount,delivered,N,delayList,relayTx,lambda,topo,cfg);
end

function out = simulateMeshPackets(topo,N,lambda,pCollision,cfg,failedPhysical)
    cn=N+1; txCount=zeros(N,1); rxCount=zeros(N,1);
    delivered=0; delayList=[]; relayTx=0;
    for src=1:N
        failed=failedPhysical;
        failed(src)=false;
        seen=false(N+1,1); seen(src)=true; frontier=src;
        firstDepth=NaN; txThis=0;
        for depth=1:cfg.meshTTL
            next=[];
            for uu=1:numel(frontier)
                u=frontier(uu);
                if u~=src && u<=N && failed(u), continue; end
                if u<=N, txCount(u)=txCount(u)+1; txThis=txThis+1; end
                recips=find(topo.feasible(u,:));
                for vv=1:numel(recips)
                    v=recips(vv);
                    if v<=N && ~topo.relayMask(v), continue; end
                    if v<=N && failed(v), continue; end
                    % A selected relay spends RX energy on duplicate receptions too;
                    % duplicate suppression happens after packet reception/caching.
                    if v<=N, rxCount(v)=rxCount(v)+1; end
                    if ~seen(v)
                        q=min(max(topo.pSingle(u,v)*pCollision,0),1);
                        pEvent=1-(1-q)^cfg.advChannels;
                        if rand<=pEvent
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
            frontier=unique(next,'stable');
            if isempty(frontier) && (~isnan(firstDepth) || depth==cfg.meshTTL), break; end
        end
        relayTx=relayTx+max(0,txThis-1);
        if ~isnan(firstDepth)
            delivered=delivered+1;
            delayList(end+1,1)=firstDepth*cfg.meshHopDelay; %#ok<AGROW>
        end
    end
    out=metricFromCounts(txCount,rxCount,delivered,N,delayList,relayTx,lambda,topo,cfg);
end

function out = metricFromCounts(txCount,rxCount,delivered,N,delayList,relayTx,lambda,topo,cfg)
    Etx=sum(txCount)*cfg.EtxEvent;
    Erx=sum(rxCount)*cfg.ErxEvent;
    Edyn=Etx+Erx;
    out.PDR=delivered/N;
    out.Esucc=Edyn/max(delivered,1);
    out.txEvents=sum(txCount); out.rxEvents=sum(rxCount);
    out.EtxRound_J=Etx; out.ErxRound_J=Erx;
    out.Ewindow_J=cfg.energyWindow_s*(lambda*Edyn+N*cfg.V*cfg.I_sleep);
    if isempty(delayList), out.delay=NaN; else, out.delay=mean(delayList); end
    out.overhead=relayTx/max(delivered,1);
    power=lambda*(txCount*cfg.EtxEvent+rxCount*cfg.ErxEvent)+cfg.V*cfg.I_sleep;
    E0=cfg.battery_mAh*1e-3*3600*cfg.V*topo.batteryFraction;
    lifeDays=E0./power/86400;
    out.FND=min(lifeDays);
    s=sort(lifeDays); out.L10=s(max(1,ceil(0.10*N)));
end

function choice = classifyArchitecture(treeP,meshP,treeE,meshE,Rmin)
    choice=3*ones(size(treeP));
    treeOK=treeP>=Rmin; meshOK=meshP>=Rmin;
    choice(treeOK & ~meshOK)=1;
    choice(~treeOK & meshOK)=2;
    both=treeOK & meshOK;
    choice(both & treeE<=meshE)=1;
    choice(both & treeE>meshE)=2;
end

function pCross = interpolateThresholdCrossing(p,y,target)
    pCross=NaN;
    for k=1:numel(p)-1
        if (y(k)-target)*(y(k+1)-target)<=0 && y(k)~=y(k+1)
            pCross=p(k)+(target-y(k))*(p(k+1)-p(k))/(y(k+1)-y(k));
            return;
        elseif y(k)==target
            pCross=p(k); return;
        end
    end
    if y(end)==target, pCross=p(end); end
end

