clear; clc; close all;
scriptDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(scriptDir);
addpath(fullfile(scriptDir,'helpers'));
dataDir = fullfile(repoRoot,'data');
outDir = fullfile(repoRoot,'figures','generated');
if ~exist(outDir,'dir'), mkdir(outDir); end
S = paper_style();
C = lines(7);

T=readtable(fullfile(dataDir,'Fig04_relay_fraction_sensitivity.csv')); pfShow=[0 0.2 0.5];
[fig,ax]=make_panel(S); hold(ax,'on');
for k=1:numel(pfShow)
 idx=abs(T.pFail-pfShow(k))<1e-12; X=sortrows(T(idx,:),'RelayFraction');
 errorbar(ax,X.RelayFraction,X.MeshPDR,X.MeshPDR_CI95,'-o','Color',C(k,:),'LineWidth',S.lineWidth,'MarkerSize',S.markerSize,'CapSize',S.capSize,'DisplayName',sprintf('p_f=%.1f',pfShow(k)));
end
yline(ax,0.95,'k--','R_{min}=0.95','HandleVisibility','off'); xlabel(ax,'Mesh relay fraction, \rho_R'); ylabel(ax,'Mesh PDR');
xlim(ax,[0.18 0.62]); ylim(ax,[0.94 1.002]); grid(ax,'on'); box(ax,'on'); legend(ax,'Location','southeast','FontSize',S.legendSize);
save_panel(fig,fullfile(outDir,'Fig04a_relay_fraction_PDR'),S);
[fig,ax]=make_panel(S); hold(ax,'on');
for k=1:numel(pfShow)
 idx=abs(T.pFail-pfShow(k))<1e-12; X=sortrows(T(idx,:),'RelayFraction');
 errorbar(ax,X.RelayFraction,X.MeshEnergy_uJ/1000,X.MeshEnergy_CI95_uJ/1000,'-o','Color',C(k,:),'LineWidth',S.lineWidth,'MarkerSize',S.markerSize,'CapSize',S.capSize,'DisplayName',sprintf('p_f=%.1f',pfShow(k)));
end
xlabel(ax,'Mesh relay fraction, \rho_R'); ylabel(ax,'Energy per delivered packet (mJ)'); xlim(ax,[0.18 0.62]); ylim(ax,[0 9]); grid(ax,'on'); box(ax,'on');
legend(ax,'Location','northwest','FontSize',S.legendSize); save_panel(fig,fullfile(outDir,'Fig04b_relay_fraction_energy'),S);
