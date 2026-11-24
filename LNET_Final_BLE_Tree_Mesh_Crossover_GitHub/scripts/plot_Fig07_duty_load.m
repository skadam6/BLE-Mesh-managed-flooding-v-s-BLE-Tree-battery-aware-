clear; clc; close all;
scriptDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(scriptDir);
addpath(fullfile(scriptDir,'helpers'));
dataDir = fullfile(repoRoot,'data');
outDir = fullfile(repoRoot,'figures','generated');
if ~exist(outDir,'dir'), mkdir(outDir); end
S = paper_style();
C = lines(7);

T=readtable(fullfile(dataDir,'Fig07a_receiver_duty_cycle_sensitivity.csv')); td=unique(T.TreeReceiveDuty); md=unique(T.MeshReceiveDuty); Z=nan(numel(md),numel(td));
for i=1:numel(md), for j=1:numel(td), idx=abs(T.MeshReceiveDuty-md(i))<1e-12 & abs(T.TreeReceiveDuty-td(j))<1e-12; Z(i,j)=T.MeshToTreeEnergyRatio(find(idx,1)); end, end
[fig,ax]=make_panel(S); imagesc(ax,100*td,100*md,Z); axis(ax,'xy'); box(ax,'on'); xlabel(ax,'Tree receive duty factor, \delta_T (%)'); ylabel(ax,'Mesh receive duty factor, \delta_M (%)'); cb=colorbar(ax); cb.Label.String='Mesh/Tree energy ratio';
save_panel(fig,fullfile(outDir,'Fig07a_receiver_duty_ratio'),S);

T=readtable(fullfile(dataDir,'Fig07b_load_failure_crossover.csv')); pf=unique(T.pFail).'; lam=unique(T.lambda); Z=nan(numel(lam),numel(pf));
for i=1:numel(lam), for j=1:numel(pf), idx=abs(T.lambda-lam(i))<1e-12 & abs(T.pFail-pf(j))<1e-12; Z(i,j)=T.ChoiceCode(find(idx,1)); end, end
[fig,ax]=make_panel(S); imagesc(ax,pf,1:numel(lam),Z); axis(ax,'xy'); box(ax,'on'); set(ax,'YTick',1:numel(lam),'YTickLabel',compose('%g',lam));
xlabel(ax,'Forwarding-unavailability probability, p_f'); ylabel(ax,'Offered load, \lambda (packet/s/node)'); colormap(ax,[0.2081 0.1663 0.5292;0.1373 0.7176 0.7176;0.9569 0.9020 0.1176]); cb=colorbar(ax); cb.Ticks=[1 2 3]; cb.TickLabels={'Tree','Mesh','Neither'};
save_panel(fig,fullfile(outDir,'Fig07b_load_failure_crossover'),S);
