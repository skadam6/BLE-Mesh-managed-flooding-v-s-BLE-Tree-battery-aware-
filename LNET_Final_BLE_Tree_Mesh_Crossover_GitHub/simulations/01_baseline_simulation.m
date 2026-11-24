%% Baseline BLE Tree vs Managed-Flooding Mesh Study
% Baseline simulation driver for the paper.
% MATLAB R2025b compatible; no specialized toolbox is required.
%
% The model preserves the user's BLE Tree rule:
%   1) nodes first reachable from the central node (CN) are one-hop nodes;
%   2) an unmarked node selects a feasible marked parent with minimum hop count;
%   3) ties are broken by the highest residual battery;
%   4) one parent per node creates a spanning tree.
%
% The BLE Mesh baseline is managed flooding with a selected relay subset,
% TTL limiting, and duplicate suppression. Both architectures use the same
% topology, received-power matrix, per-link decoding model, traffic rate,
% packet size, energy parameters, and failure realization.
%
% IMPORTANT MODELING CHOICE:
% Data forwarding is compared on a common BLE advertising-event abstraction.
% One logical transmission sends the same network packet on primary advertising
% channels 37, 38, and 39. This isolates Tree-vs-Mesh forwarding effects.
% The model is not a bit-exact implementation of a commercial BLE stack.

clc; close all;

cfg = defaultConfig();

% Set true for a fast sanity run; keep false for paper-quality Monte Carlo runs.
cfg.quickMode = false;
if cfg.quickMode
    cfg.nTrialsMain = 20;
    cfg.nTrialsMap  = 12;
else
    cfg.nTrialsMain = 100;
    cfg.nTrialsMap  = 60;
end

fprintf('BLE Tree vs Mesh study\n');
fprintf('Random seed = %d\n', cfg.seed);
fprintf('Trials: main=%d, map=%d\n', cfg.nTrialsMain, cfg.nTrialsMap);
fprintf('Default: N=%d, p_f=%.2f, lambda=%.2f packet/s/node\n', ...
    cfg.Ndefault, cfg.pFailDefault, cfg.lambdaDefault);

%% 1) Network-size sweep
Nvec  = 10:10:200;
%Nvec = [20 40 60 80 100 120 150];
sizeTree = repmat(emptyMetric(), numel(Nvec), 1);
sizeMesh = repmat(emptyMetric(), numel(Nvec), 1);
for k = 1:numel(Nvec)
    fprintf('Size sweep: N=%d\n', Nvec(k));
    [sizeTree(k), sizeMesh(k)] = runPoint(Nvec(k), cfg.pFailDefault, ...
        cfg.lambdaDefault, cfg, cfg.nTrialsMain, cfg.seed + 1000 + Nvec(k));
end

fig = figure('Color','w');
errorbar(Nvec, 1e6*[sizeTree.Esucc], 1e6*[sizeTree.EsuccCI], '-o', ...
    'LineWidth',1.25,'MarkerSize',5); hold on;
errorbar(Nvec, 1e6*[sizeMesh.Esucc], 1e6*[sizeMesh.EsuccCI], '-s', ...
    'LineWidth',1.25,'MarkerSize',5);
grid on; box on;
xlabel('Number of BLE sensor nodes, N');
ylabel('Energy per delivered packet (\muJ)');
legend('Battery-aware Tree','Managed-flooding Mesh','Location','northwest');
set(gca,'FontName','Times New Roman','FontSize',9,'YScale','log');
exportFigure(fig, 'results/fig2_energy_vs_nodes');

%% 2) Relay-failure sweep
pfVec = 0:0.05:0.50;%0.30
failTree = repmat(emptyMetric(), numel(pfVec), 1);
failMesh = repmat(emptyMetric(), numel(pfVec), 1);
for k = 1:numel(pfVec)
    fprintf('Failure sweep: p_f=%.2f\n', pfVec(k));
    [failTree(k), failMesh(k)] = runPoint(cfg.Ndefault, pfVec(k), ...
        cfg.lambdaDefault, cfg, cfg.nTrialsMain, cfg.seed + 2000 + round(1000*pfVec(k)));
end

fig = figure('Color','w');
errorbar(pfVec, [failTree.PDR], [failTree.PDRCI], '-o', ...
    'LineWidth',1.25,'MarkerSize',5); hold on;
errorbar(pfVec, [failMesh.PDR], [failMesh.PDRCI], '-s', ...
    'LineWidth',1.25,'MarkerSize',5);
yline(cfg.reliabilityTarget,'--','Reliability target','LabelHorizontalAlignment','left');
grid on; box on; ylim([0 1.02]);
xlabel('Independent relay failure probability, p_f');
ylabel('Packet delivery ratio');
legend('Battery-aware Tree','Managed-flooding Mesh','Location','southwest');
set(gca,'FontName','Times New Roman','FontSize',9);
exportFigure(fig, 'results/fig3_pdr_vs_failure');

%% 3) Offered-load sweep
lambdaVec = [0.02 0.05 0.1 0.2 0.5 1 2];
loadTree = repmat(emptyMetric(), numel(lambdaVec), 1);
loadMesh = repmat(emptyMetric(), numel(lambdaVec), 1);
for k = 1:numel(lambdaVec)
    fprintf('Load sweep: lambda=%.2f packet/s/node\n', lambdaVec(k));
    [loadTree(k), loadMesh(k)] = runPoint(cfg.Ndefault, cfg.pFailDefault, ...
        lambdaVec(k), cfg, cfg.nTrialsMain, cfg.seed + 3000 + round(100*lambdaVec(k)));
end

fig = figure('Color','w');
errorbar(lambdaVec, 1e3*[loadTree.delay], 1e3*[loadTree.delayCI], '-o', ...
    'LineWidth',1.25,'MarkerSize',5); hold on;
errorbar(lambdaVec, 1e3*[loadMesh.delay], 1e3*[loadMesh.delayCI], '-s', ...
    'LineWidth',1.25,'MarkerSize',5);
grid on; box on;
xlabel('Offered load, \lambda (packet/s/node)');
ylabel('Mean end-to-end delay (ms)');
legend('Battery-aware Tree','Managed-flooding Mesh','Location','northwest');
set(gca,'FontName','Times New Roman','FontSize',9,'XScale','log');
exportFigure(fig, 'results/fig4_delay_vs_load');

%% 4) Communication-induced first-node-death lifetime
% Use p_f = 0 here so battery depletion is not conflated with an exogenous
% relay-failure realization. The same traffic/channel assumptions are retained.
lifeTree = repmat(emptyMetric(), numel(Nvec), 1);
lifeMesh = repmat(emptyMetric(), numel(Nvec), 1);
for k = 1:numel(Nvec)
    fprintf('Lifetime sweep: N=%d (p_f=0)\n', Nvec(k));
    [lifeTree(k), lifeMesh(k)] = runPoint(Nvec(k), 0, ...
        cfg.lambdaDefault, cfg, cfg.nTrialsMain, cfg.seed + 5000 + Nvec(k));
end

fig = figure('Color','w');
errorbar(Nvec, [lifeTree.FNDdays], [lifeTree.FNDdaysCI], '-o', ...
    'LineWidth',1.25,'MarkerSize',5); hold on;
errorbar(Nvec, [lifeMesh.FNDdays], [lifeMesh.FNDdaysCI], '-s', ...
    'LineWidth',1.25,'MarkerSize',5);
grid on; box on;
xlabel('Number of BLE sensor nodes, N');
ylabel('First-node-death lifetime (days)');
legend('Battery-aware Tree','Managed-flooding Mesh','Location','southwest');
set(gca,'FontName','Times New Roman','FontSize',9,'YScale','log');
exportFigure(fig, 'results/fig5_lifetime_vs_nodes');

%% 5) Reliability-constrained energy crossover map
% Architecture selection criterion:
%   minimize E_succ subject to PDR >= R_min.
% Code values: 1 = Tree, 2 = Mesh, 3 = neither satisfies R_min.
%Nmap  = [20 40 60 80 100 120 150];
Nmap  = 10:10:200;
pfMap = 0:0.05:0.50;%0:0.05:0.30;
choice = zeros(numel(Nmap), numel(pfMap));
mapTreePDR = zeros(size(choice)); mapMeshPDR = zeros(size(choice));
mapTreeE = zeros(size(choice));   mapMeshE = zeros(size(choice));
for i = 1:numel(Nmap)
    for j = 1:numel(pfMap)
        fprintf('Crossover map: N=%d, p_f=%.2f\n', Nmap(i), pfMap(j));
        [t, m] = runPoint(Nmap(i), pfMap(j), cfg.lambdaDefault, cfg, ...
            cfg.nTrialsMap, cfg.seed + 4000 + 10*Nmap(i) + j);
        mapTreePDR(i,j) = t.PDR; mapMeshPDR(i,j) = m.PDR;
        mapTreeE(i,j) = t.Esucc; mapMeshE(i,j) = m.Esucc;
        treeOK = t.PDR >= cfg.reliabilityTarget;
        meshOK = m.PDR >= cfg.reliabilityTarget;
        if treeOK && meshOK
            if t.Esucc <= m.Esucc
                choice(i,j) = 1;
            else
                choice(i,j) = 2;
            end
        elseif treeOK
            choice(i,j) = 1;
        elseif meshOK
            choice(i,j) = 2;
        else
            choice(i,j) = 3;
        end
    end
end

fig = figure('Color','w');
imagesc(pfMap, Nmap, choice);
set(gca,'YDir','normal','FontName','Times New Roman','FontSize',9);
colormap(parula(3));
cb = colorbar; cb.Ticks = [1 2 3]; cb.TickLabels = {'Tree','Mesh','Neither'};
xlabel('Independent relay failure probability, p_f');
ylabel('Number of BLE sensor nodes, N');
title(sprintf('Min-energy architecture subject to PDR \geq %.2f', cfg.reliabilityTarget));
exportFigure(fig, 'results/fig6_crossover_map');

%% Save numerical results
Tsize = table(Nvec(:), [sizeTree.PDR].', [sizeMesh.PDR].', ...
    1e6*[sizeTree.Esucc].', 1e6*[sizeMesh.Esucc].', ...
    [sizeTree.Ewindow_J].', [sizeMesh.Ewindow_J].', ...
    [sizeTree.txEvents].', [sizeMesh.txEvents].', ...
    [sizeTree.rxEvents].', [sizeMesh.rxEvents].', ...
    1e3*[sizeTree.delay].', 1e3*[sizeMesh.delay].', ...
    [sizeTree.overhead].', [sizeMesh.overhead].', ...
    'VariableNames', {'N','TreePDR','MeshPDR','TreeEnergy_uJ','MeshEnergy_uJ', ...
    'TreeTotalEnergy1h_J','MeshTotalEnergy1h_J','TreeTxEvents','MeshTxEvents', ...
    'TreeRxEvents','MeshRxEvents','TreeDelay_ms','MeshDelay_ms', ...
    'TreeOverhead','MeshOverhead'});
writetable(Tsize,'results/size_sweep.csv');

Tlife = table(Nvec(:), [lifeTree.FNDdays].', [lifeMesh.FNDdays].', ...
    [lifeTree.L10days].', [lifeMesh.L10days].', ...
    'VariableNames', {'N','TreeFND_days','MeshFND_days','TreeL10_days','MeshL10_days'});
writetable(Tlife,'results/lifetime_sweep.csv');

Tfail = table(pfVec(:), [failTree.PDR].', [failMesh.PDR].', ...
    1e6*[failTree.Esucc].', 1e6*[failMesh.Esucc].', ...
    'VariableNames', {'pFail','TreePDR','MeshPDR','TreeEnergy_uJ','MeshEnergy_uJ'});
writetable(Tfail,'results/failure_sweep.csv');

Tload = table(lambdaVec(:), [loadTree.PDR].', [loadMesh.PDR].', ...
    1e3*[loadTree.delay].', 1e3*[loadMesh.delay].', ...
    [loadTree.overhead].', [loadMesh.overhead].', ...
    'VariableNames', {'lambda','TreePDR','MeshPDR','TreeDelay_ms','MeshDelay_ms','TreeOverhead','MeshOverhead'});
writetable(Tload,'results/load_sweep.csv');

writematrix(choice,'results/crossover_choice.csv');
writematrix(mapTreePDR,'results/crossover_tree_pdr.csv');
writematrix(mapMeshPDR,'results/crossover_mesh_pdr.csv');
writematrix(1e6*mapTreeE,'results/crossover_tree_energy_uJ.csv');
writematrix(1e6*mapMeshE,'results/crossover_mesh_energy_uJ.csv');

fprintf('\nStudy complete. Figures and CSV files are in ./results/.\n');
fprintf('Crossover rule: minimum energy among architectures satisfying PDR >= %.2f.\n', cfg.reliabilityTarget);

%% ========================= Local functions ==============================
function cfg = defaultConfig()
    cfg.seed = 17;
    cfg.quickMode = false;
    cfg.nTrialsMain = 100;
    cfg.nTrialsMap = 60;

    % Common deployment/channel model
    cfg.areaSide = 100;             % m, square deployment
    cfg.txPower_dBm = 0;            % common Tx power
    cfg.PL0_dB = 40;                % reference path loss at d0=1 m
    cfg.d0 = 1;                     % m
    cfg.pathLossExp = 3.0;
    cfg.sigmaShadow_dB = 3.0;       % topology-scale log-normal shadowing
    cfg.sigmaFast_dB = 2.5;         % packet-scale received-power fluctuation
    cfg.rxThreshold_dBm = -90;      % operating threshold; keeps 5 dB margin vs typical -95 dBm 1M sensitivity

    % Packet/radio energy abstraction
    cfg.airBytes = 47;              % maximum-sized unsegmented BLE advertising packet used for common comparison
    cfg.phyRate = 1e6;              % 1M PHY, bit/s
    cfg.advChannels = 3;            % channels 37, 38, 39
    cfg.V = 3.0;                    % V
    cfg.I_tx = 4.8e-3;              % A at 0 dBm, representative nRF52840 value
    cfg.I_rx = 4.6e-3;              % A, 1M RX representative nRF52840 value
    cfg.I_sleep = 2e-6;             % A, common background term; sensitivity parameter
    cfg.battery_mAh = 235;          % representative coin-cell capacity
    cfg.batteryResidualRange = [0.85 1.00];
    cfg.energyWindow_s = 3600;       % report total sensor energy over a 1-hour observation window

    cfg.tPDU = 8*cfg.airBytes/cfg.phyRate;
    cfg.EtxEvent = cfg.advChannels * cfg.V * cfg.I_tx * cfg.tPDU;
    cfg.ErxEvent = cfg.V * cfg.I_rx * cfg.tPDU;

    % Tree/Mesh forwarding settings
    cfg.treeHopDelay = 0.010;        % s, forwarding-service abstraction per successful hop
    cfg.meshHopDelay = 0.015;        % s, includes a small relay/backoff increment
    cfg.meshRelayFraction = 0.40;    % selected relays; not every node retransmits
    cfg.meshTTL = 6;

    % Traffic/failure defaults
    cfg.Ndefault = 80;
    cfg.lambdaDefault = 0.10;        % packet/s/node = one packet every 10 s
    cfg.pFailDefault = 0.05;
    cfg.reliabilityTarget = 0.95;
end

function m = emptyMetric()
    m = struct('PDR',NaN,'PDRCI',NaN,'Esucc',NaN,'EsuccCI',NaN, ...
        'delay',NaN,'delayCI',NaN,'overhead',NaN,'overheadCI',NaN, ...
        'FNDdays',NaN,'FNDdaysCI',NaN,'L10days',NaN,'L10daysCI',NaN, ...
        'collisionFactor',NaN,'meanLogicalTx',NaN,'Ewindow_J',NaN, ...
        'txEvents',NaN,'rxEvents',NaN);
end

function [treeOut, meshOut] = runPoint(N, pFail, lambda, cfg, nTrials, seed)
    rng(seed,'twister');
    treeVals = nan(nTrials,11);
    meshVals = nan(nTrials,11);
    for tr = 1:nTrials
        topo = generateTopology(N,cfg);
        [treeVals(tr,:), meshVals(tr,:)] = simulateTrial(topo,N,pFail,lambda,cfg);
    end
    treeOut = packMetric(treeVals);
    meshOut = packMetric(meshVals);
end

function out = packMetric(X)
    % Columns: PDR, Esucc, delay, overhead, FND, L10, pCollision, meanTx, Ewindow, txEvents, rxEvents
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
end

function y = meanNoNaN(x)
    x = x(~isnan(x));
    if isempty(x), y = NaN; else, y = mean(x); end
end

function y = ci95(x)
    x = x(~isnan(x));
    if numel(x) <= 1
        y = 0;
    else
        y = 1.96*std(x,0)/sqrt(numel(x));
    end
end

function topo = generateTopology(N,cfg)
    cn = N+1;
    pos = [cfg.areaSide*rand(N,2); cfg.areaSide/2, cfg.areaSide/2];
    dx = pos(:,1)-pos(:,1).';
    dy = pos(:,2)-pos(:,2).';
    D = max(sqrt(dx.^2+dy.^2),cfg.d0);

    Z = cfg.sigmaShadow_dB*randn(N+1);
    Z = triu(Z,1);               % one independent shadowing sample per undirected link
    Z = Z + Z.';                 % reciprocal mean-power realization, preserving sigmaShadow_dB
    Z(1:N+2:end) = 0;
    Pr = cfg.txPower_dBm - cfg.PL0_dB - 10*cfg.pathLossExp*log10(D/cfg.d0) + Z;
    Pr(1:N+2:end) = -Inf;

    feasible = Pr >= cfg.rxThreshold_dBm;
    z = (cfg.rxThreshold_dBm-Pr)/(sqrt(2)*cfg.sigmaFast_dB);
    pSingle = 0.5*erfc(z);
    pSingle(1:N+2:end) = 0;

    b0 = cfg.batteryResidualRange(1) + diff(cfg.batteryResidualRange)*rand(N,1);
    [parent,hop] = buildBatteryAwareTree(feasible,b0,N);

    degree = sum(feasible(1:N,:),2);
    nRelay = max(1,ceil(cfg.meshRelayFraction*N));
    [~,order] = sort(degree,'descend');
    relayMask = false(N,1);
    relayMask(order(1:nRelay)) = true;

    topo.pos = pos;
    topo.feasible = feasible;
    topo.pSingle = pSingle;
    topo.parent = parent;
    topo.hop = hop;
    topo.relayMask = relayMask;
    topo.batteryFraction = b0;
    topo.cn = cn;
end

function [parent,hopSensor] = buildBatteryAwareTree(feasible,batteryFraction,N)
    cn = N+1;
    marked = false(N+1,1); marked(cn)=true;
    hop = inf(N+1,1); hop(cn)=0;
    parent = zeros(N,1);

    for layer = 1:N
        markedIdx = find(marked);
        newNodes = [];
        newParents = [];
        newHops = [];
        for i = 1:N
            if marked(i), continue; end
            cand = markedIdx(feasible(i,markedIdx));
            if isempty(cand), continue; end
            minHop = min(hop(cand));
            pool = cand(hop(cand)==minHop);
            if any(pool==cn)
                p = cn;
            else
                [~,ii] = max(batteryFraction(pool));
                p = pool(ii);
            end
            newNodes(end+1,1) = i; %#ok<AGROW>
            newParents(end+1,1) = p; %#ok<AGROW>
            newHops(end+1,1) = minHop+1; %#ok<AGROW>
        end
        if isempty(newNodes), break; end
        for q = 1:numel(newNodes)
            i = newNodes(q);
            marked(i)=true; parent(i)=newParents(q); hop(i)=newHops(q);
        end
    end
    hopSensor = hop(1:N);
end

function path = treePath(src,parent,N)
    cn = N+1;
    path = zeros(0,2);
    u = src;
    visited = false(N+1,1);
    while u~=cn && u>0 && ~visited(u)
        visited(u)=true;
        v = parent(u);
        if v==0
            path = zeros(0,2);
            return;
        end
        path(end+1,:) = [u v]; %#ok<AGROW>
        u = v;
    end
    if u~=cn, path = zeros(0,2); end
end

function nTx = deterministicMeshTx(feasible,relayMask,src,N,ttl)
    cn = N+1;
    seen = false(N+1,1); seen(src)=true;
    frontier = src;
    nTx = 0;
    for depth = 1:ttl
        next = [];
        for uu = 1:numel(frontier)
            u = frontier(uu);
            nTx = nTx + 1;
            recips = find(feasible(u,:));
            for vv = 1:numel(recips)
                v = recips(vv);
                if v==cn
                    seen(v)=true;
                elseif relayMask(v) && ~seen(v)
                    seen(v)=true;
                    next(end+1,1)=v; %#ok<AGROW>
                end
            end
        end
        frontier = unique(next,'stable');
        if isempty(frontier), break; end
    end
end

function [treeVec,meshVec] = simulateTrial(topo,N,pFail,lambda,cfg)
    paths = cell(N,1);
    pathLens = nan(N,1);
    meshTx0 = zeros(N,1);
    for s = 1:N
        paths{s} = treePath(s,topo.parent,N);
        if ~isempty(paths{s}), pathLens(s)=size(paths{s},1); end
        meshTx0(s) = deterministicMeshTx(topo.feasible,topo.relayMask,s,N,cfg.meshTTL);
    end
    meanTreeTx = meanNoNaN(pathLens);
    if isnan(meanTreeTx), meanTreeTx = 1; end
    meanMeshTx = mean(meshTx0);

    % Pure-ALOHA-style collision approximation per advertising channel.
    % Each logical message is emitted once on each primary advertising channel.
    Gtree = lambda*N*meanTreeTx*cfg.tPDU;
    Gmesh = lambda*N*meanMeshTx*cfg.tPDU;
    pColTree = exp(-2*Gtree);
    pColMesh = exp(-2*Gmesh);

    tree = simulateTreePackets(topo,paths,N,pFail,lambda,pColTree,cfg);
    mesh = simulateMeshPackets(topo,N,pFail,lambda,pColMesh,cfg);

    treeVec = [tree.PDR tree.Esucc tree.delay tree.overhead tree.FND tree.L10 pColTree meanTreeTx tree.Ewindow_J tree.txEvents tree.rxEvents];
    meshVec = [mesh.PDR mesh.Esucc mesh.delay mesh.overhead mesh.FND mesh.L10 pColMesh meanMeshTx mesh.Ewindow_J mesh.txEvents mesh.rxEvents];
end

function out = simulateTreePackets(topo,paths,N,pFail,lambda,pCollision,cfg)
    cn = N+1;
    txCount = zeros(N,1); rxCount = zeros(N,1);
    delivered = 0; delayList = []; relayTx = 0;

    for src = 1:N
        failed = rand(N,1) < pFail;
        failed(src) = false; % reliability is conditioned on an operating source
        path = paths{src};
        if isempty(path), continue; end
        ok = true; hopsAttempted = 0;
        for h = 1:size(path,1)
            u = path(h,1); v = path(h,2);
            if u~=src && failed(u), ok=false; break; end
            hopsAttempted = hopsAttempted+1;
            txCount(u)=txCount(u)+1;
            if v<=N
                if failed(v), ok=false; break; end
                rxCount(v)=rxCount(v)+1;
            end
            % A logical advertising event uses channels 37/38/39. Assuming
            % independent per-channel outcomes, at least one successful copy
            % yields the event success below.
            q = min(max(topo.pSingle(u,v)*pCollision,0),1);
            pEvent = 1-(1-q)^cfg.advChannels;
            if rand > pEvent, ok=false; break; end
        end
        relayTx = relayTx + max(0,hopsAttempted-1);
        if ok
            delivered = delivered+1;
            delayList(end+1,1)=hopsAttempted*cfg.treeHopDelay; %#ok<AGROW>
        end
    end

    out = metricFromCounts(txCount,rxCount,delivered,N,delayList,relayTx,lambda,topo,cfg);
end

function out = simulateMeshPackets(topo,N,pFail,lambda,pCollision,cfg)
    cn = N+1;
    txCount = zeros(N,1); rxCount = zeros(N,1);
    delivered = 0; delayList = []; relayTx = 0;

    for src = 1:N
        failed = rand(N,1) < pFail;
        failed(src)=false;
        seen = false(N+1,1); seen(src)=true;
        frontier = src;
        firstDepth = NaN;
        txThis = 0;

        for depth = 1:cfg.meshTTL
            next = [];
            for uu = 1:numel(frontier)
                u = frontier(uu);
                if u~=src && u<=N && failed(u), continue; end
                if u<=N
                    txCount(u)=txCount(u)+1;
                    txThis=txThis+1;
                end
                recips = find(topo.feasible(u,:));
                for vv = 1:numel(recips)
                    v = recips(vv);
                    if v<=N && ~topo.relayMask(v), continue; end
                    if v<=N && failed(v), continue; end
                    % Selected relays scan and spend RX energy even when the
                    % packet is a duplicate or cannot be decoded.
                    if v<=N, rxCount(v)=rxCount(v)+1; end
                    if ~seen(v)
                        q = min(max(topo.pSingle(u,v)*pCollision,0),1);
                        pEvent = 1-(1-q)^cfg.advChannels;
                        if rand <= pEvent
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
            frontier = unique(next,'stable');
            if isempty(frontier) && (~isnan(firstDepth) || depth==cfg.meshTTL)
                break;
            end
        end
        relayTx = relayTx + max(0,txThis-1);
        if ~isnan(firstDepth)
            delivered=delivered+1;
            delayList(end+1,1)=firstDepth*cfg.meshHopDelay; %#ok<AGROW>
        end
    end

    out = metricFromCounts(txCount,rxCount,delivered,N,delayList,relayTx,lambda,topo,cfg);
end

function out = metricFromCounts(txCount,rxCount,delivered,N,delayList,relayTx,lambda,topo,cfg)
    Edyn = sum(txCount)*cfg.EtxEvent + sum(rxCount)*cfg.ErxEvent;
    out.PDR = delivered/N;
    out.Esucc = Edyn/max(delivered,1);
    out.txEvents = sum(txCount);
    out.rxEvents = sum(rxCount);
    % One Monte Carlo round injects one packet from every source. At lambda
    % packets/s/node, lambda such rounds occur per second in expectation.
    % Add the common background term to report total sensor energy over the
    % frozen one-hour observation window.
    out.Ewindow_J = cfg.energyWindow_s*(lambda*Edyn + N*cfg.V*cfg.I_sleep);
    if isempty(delayList), out.delay=NaN; else, out.delay=mean(delayList); end
    out.overhead = relayTx/max(delivered,1);

    % Communication-induced lifetime: common sleep term + event energy.
    % Continuous scanning current is intentionally not added to the primary
    % comparison; doing so would make the result hardware/role-specific and
    % would further penalize always-on Mesh relay nodes.
    power = lambda*(txCount*cfg.EtxEvent + rxCount*cfg.ErxEvent) + cfg.V*cfg.I_sleep;
    E0 = cfg.battery_mAh*1e-3*3600*cfg.V*topo.batteryFraction;
    lifeDays = E0./power/86400;
    out.FND = min(lifeDays);
    s = sort(lifeDays);
    out.L10 = s(max(1,ceil(0.10*N)));
end

function exportFigure(fig,baseName)
    savefig(fig,[baseName '.fig']);
    exportgraphics(fig,[baseName '.pdf'],'ContentType','vector');
    exportgraphics(fig,[baseName '.png'],'Resolution',300);
end
