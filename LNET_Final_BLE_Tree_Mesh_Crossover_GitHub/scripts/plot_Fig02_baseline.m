clear; clc; close all;
scriptDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(scriptDir);
addpath(fullfile(scriptDir,'helpers'));
dataDir = fullfile(repoRoot,'data');
outDir = fullfile(repoRoot,'figures','generated');
if ~exist(outDir,'dir'), mkdir(outDir); end
S = paper_style();
C = lines(7);

%% Fig. 2(a): energy versus network size
T = readtable(fullfile(dataDir,'Fig02a_energy_vs_nodes.csv'));
[fig,ax] = make_panel(S); hold(ax,'on');
plot(ax,T.N,T.TreeEnergy_uJ,'-o','LineWidth',S.lineWidth,'MarkerSize',S.markerSize,'DisplayName','Battery-aware Tree');
plot(ax,T.N,T.MeshEnergy_uJ,'-s','LineWidth',S.lineWidth,'MarkerSize',S.markerSize,'DisplayName','Managed-flooding Mesh');
set(ax,'YScale','log'); grid(ax,'on'); box(ax,'on');
xlabel(ax,'Number of BLE sensor nodes, N'); ylabel(ax,'Energy per delivered packet (\muJ)');
legend(ax,'Location','northwest','FontSize',S.legendSize);
save_panel(fig,fullfile(outDir,'Fig02a_energy_vs_nodes'),S);

%% Fig. 2(b): PDR versus forwarding unavailability
T = readtable(fullfile(dataDir,'Fig02b_pdr_vs_unavailability.csv'));
[fig,ax] = make_panel(S); hold(ax,'on');
plot(ax,T.pFail,T.TreePDR,'-o','LineWidth',S.lineWidth,'MarkerSize',S.markerSize,'DisplayName','Battery-aware Tree');
plot(ax,T.pFail,T.MeshPDR,'-s','LineWidth',S.lineWidth,'MarkerSize',S.markerSize,'DisplayName','Managed-flooding Mesh');
yline(ax,0.95,'k--','Reliability target','HandleVisibility','off');
grid(ax,'on'); box(ax,'on'); ylim(ax,[0.7 1.01]);
xlabel(ax,'Forwarding-unavailability probability, p_f'); ylabel(ax,'Packet delivery ratio');
legend(ax,'Location','southwest','FontSize',S.legendSize);
save_panel(fig,fullfile(outDir,'Fig02b_pdr_vs_unavailability'),S);
