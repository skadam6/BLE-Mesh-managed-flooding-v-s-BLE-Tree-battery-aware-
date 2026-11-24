clear; clc; close all;
scriptDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(scriptDir);
addpath(fullfile(scriptDir,'helpers'));
dataDir = fullfile(repoRoot,'data');
outDir = fullfile(repoRoot,'figures','generated');
if ~exist(outDir,'dir'), mkdir(outDir); end
S = paper_style();
C = lines(7);

MK={'o','s','d'};
T=readtable(fullfile(dataDir,'Fig06a_failure_model_sensitivity.csv')); modes=unique(T.FailureMode,'stable'); labels={'Transient','Persistent independent','Persistent correlated'};
[fig,ax]=make_panel(S); hold(ax,'on');
for k=1:numel(modes)
 idx=strcmp(T.FailureMode,modes{k}); X=sortrows(T(idx,:),'pFail');
 errorbar(ax,X.pFail,X.TreePDR,X.TreePDR_CI95,['-' MK{k}],'Color',C(k,:),'LineWidth',S.lineWidth,'MarkerSize',S.markerSize,'CapSize',S.capSize,'DisplayName',labels{k});
end
yline(ax,0.95,'k--','R_{min}=0.95','HandleVisibility','off'); xlabel(ax,'Forwarding-unavailability probability, p_f'); ylabel(ax,'Tree PDR');
xlim(ax,[0.04 0.41]); ylim(ax,[0.84 0.98]); grid(ax,'on'); box(ax,'on'); legend(ax,'Location','southwest','FontSize',S.legendSize);
save_panel(fig,fullfile(outDir,'Fig06a_failure_models'),S);

T=readtable(fullfile(dataDir,'Fig06b_tree_retry_reconstruction.csv')); configs=unique(T.TreeConfiguration,'stable'); labels={'No retry, no repair','One retry, no repair','One retry + reconstruction'};
[fig,ax]=make_panel(S); hold(ax,'on');
for k=1:numel(configs)
 idx=strcmp(T.TreeConfiguration,configs{k}); X=sortrows(T(idx,:),'pFail');
 errorbar(ax,X.pFail,X.TreePDR,X.TreePDR_CI95,['-' MK{k}],'Color',C(k,:),'LineWidth',S.lineWidth,'MarkerSize',S.markerSize,'CapSize',S.capSize,'DisplayName',labels{k});
end
yline(ax,0.95,'k--','R_{min}=0.95','HandleVisibility','off'); xlabel(ax,'Persistent-unavailability probability, p_f'); ylabel(ax,'Tree PDR');
xlim(ax,[0.04 0.31]); ylim(ax,[0.84 1.005]); grid(ax,'on'); box(ax,'on'); legend(ax,'Location','southwest','FontSize',S.legendSize);
save_panel(fig,fullfile(outDir,'Fig06b_tree_recovery'),S);
