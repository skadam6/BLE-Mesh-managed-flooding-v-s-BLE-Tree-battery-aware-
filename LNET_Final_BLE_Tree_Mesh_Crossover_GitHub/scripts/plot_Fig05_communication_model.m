clear; clc; close all;
scriptDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(scriptDir);
addpath(fullfile(scriptDir,'helpers'));
dataDir = fullfile(repoRoot,'data');
outDir = fullfile(repoRoot,'figures','generated');
if ~exist(outDir,'dir'), mkdir(outDir); end
S = paper_style();
C = lines(7);

T=readtable(fullfile(dataDir,'Fig05_communication_model_sensitivity.csv')); models=unique(T.Model,'stable');
labels={'Global, independent','Local, independent','Local, \rho_c=0.5','Local, \rho_c=1'}; MK={'o','s','d','^'};
for arch=1:2
 [fig,ax]=make_panel(S); hold(ax,'on');
 for k=1:numel(models)
  idx=strcmp(T.Model,models{k}); X=sortrows(T(idx,:),'lambda');
  if arch==1, y=X.TreePDR; e=X.TreePDR_CI95; else, y=X.MeshPDR; e=X.MeshPDR_CI95; end
  errorbar(ax,X.lambda,y,e,['-' MK{k}],'Color',C(k,:),'LineWidth',S.lineWidth,'MarkerSize',S.markerSize,'CapSize',S.capSize,'DisplayName',labels{k});
 end
 yline(ax,0.95,'k--','R_{min}=0.95','HandleVisibility','off'); set(ax,'XScale','log'); xlabel(ax,'Offered load, \lambda (packet/s/node)'); grid(ax,'on'); box(ax,'on');
 if arch==1, ylabel(ax,'Tree PDR'); ylim(ax,[0.80 1.01]); base='Fig05a_communication_model_Tree_PDR';
 else, ylabel(ax,'Mesh PDR'); ylim(ax,[0.10 1.01]); base='Fig05b_communication_model_Mesh_PDR'; end
 legend(ax,'Location','southwest','FontSize',S.legendSize); save_panel(fig,fullfile(outDir,base),S);
end
