clear; clc; close all;
scriptDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(scriptDir);
addpath(fullfile(scriptDir,'helpers'));
dataDir = fullfile(repoRoot,'data');
outDir = fullfile(repoRoot,'figures','generated');
if ~exist(outDir,'dir'), mkdir(outDir); end
S = paper_style();
C = lines(7);

%% Fig. 3(a): reliability-constrained crossover map
Nmap = 10:10:200; pfMap = 0:0.05:0.50; Rmin = 0.95;
TreePDR = readmatrix(fullfile(dataDir,'Fig03a_tree_pdr_grid.csv'));
MeshPDR = readmatrix(fullfile(dataDir,'Fig03a_mesh_pdr_grid.csv'));
TreeE = readmatrix(fullfile(dataDir,'Fig03a_tree_energy_uJ_grid.csv'));
MeshE = readmatrix(fullfile(dataDir,'Fig03a_mesh_energy_uJ_grid.csv'));
Nq=(10:1:200).'; pfq=0:0.0025:0.50; [PFQ,NQ]=meshgrid(pfq,Nq);
TPq=interp2(pfMap,Nmap,TreePDR,PFQ,NQ,'linear'); MPq=interp2(pfMap,Nmap,MeshPDR,PFQ,NQ,'linear');
TEq=interp2(pfMap,Nmap,TreeE,PFQ,NQ,'linear'); MEq=interp2(pfMap,Nmap,MeshE,PFQ,NQ,'linear');
choice=3*ones(size(TPq)); treeOK=TPq>=Rmin; meshOK=MPq>=Rmin;
choice(treeOK & ~meshOK)=1; choice(~treeOK & meshOK)=2;
both=treeOK & meshOK; choice(both & TEq<=MEq)=1; choice(both & TEq>MEq)=2;
Tc=readtable(fullfile(dataDir,'Fig03a_tree_crossings_300_trials.csv'));
p=polyfit(Tc.N,Tc.EstimatedTreeCrossing_pFail,1); Nline=linspace(min(Tc.N),max(Tc.N),300); pLine=polyval(p,Nline);
[fig,ax]=make_panel(S); imagesc(ax,pfq,Nq,choice); axis(ax,'xy'); hold(ax,'on'); colormap(ax,parula(3));
cb=colorbar(ax); cb.Ticks=[1 2 3]; cb.TickLabels={'Tree','Mesh','Neither'};
plot(ax,pLine,Nline,'k-','LineWidth',1.5,'DisplayName','Boundary fit');
plot(ax,Tc.EstimatedTreeCrossing_pFail,Tc.N,'ko','MarkerFaceColor','w','MarkerSize',4.5,'LineWidth',1,'DisplayName','300-trial crossings');
xlabel(ax,'Forwarding-unavailability probability, p_f'); ylabel(ax,'Number of BLE nodes, N'); box(ax,'on');
lgd=legend(ax,'Location','northeast','FontSize',6.5,'Box','on'); try, lgd.ItemTokenSize=[10 7]; end
save_panel(fig,fullfile(outDir,'Fig03a_crossover_map'),S);

%% Fig. 3(b): geometry / hop-count dependence
T=readtable(fullfile(dataDir,'Fig03b_geometry_hop_sensitivity.csv'));
[grp,~,sweepType,sweepValue]=findgroups(T.SettingID,T.SweepType,T.SweepValue);
meanH=splitapply(@(x)x(1),T.MeanTreeHop,grp); crossV=splitapply(@(x)x(1),T.TreeCrossingEstimate,grp);
[fig,ax]=make_panel(S); hold(ax,'on'); xlim(ax,[0.94 2.08]); ylim(ax,[0.04 0.27]);
for k=1:numel(sweepType)
    y=crossV(k); noCross=isnan(y); if noCross, y=0.25; end
    if strcmp(sweepType{k},'Area'), col=C(1,:); mk='o'; lbl=sprintf('%g m',sweepValue(k));
    else, col=C(2,:); mk='s'; lbl=sprintf('\\eta=%g',sweepValue(k)); end
    plot(ax,meanH(k),y,mk,'Color',col,'MarkerFaceColor','none','MarkerSize',S.markerSize+1,'LineWidth',S.lineWidth);
    if noCross, plot(ax,meanH(k),y,'^','Color',col,'MarkerFaceColor','none','MarkerSize',S.markerSize+2,'LineWidth',S.lineWidth); end
    if strcmp(sweepType{k},'Area') && sweepValue(k)>=100
        text(ax,meanH(k)-0.02,y+0.004,lbl,'HorizontalAlignment','right','FontName',S.fontName,'FontSize',S.legendSize);
    elseif contains(string(sweepType{k}),'PathLoss') && abs(sweepValue(k)-3.5)<1e-12
        text(ax,meanH(k)+0.015,y+0.002,lbl,'HorizontalAlignment','left','FontName',S.fontName,'FontSize',S.legendSize);
    else
        text(ax,meanH(k)+0.015,y+0.004,lbl,'HorizontalAlignment','left','FontName',S.fontName,'FontSize',S.legendSize);
    end
end
h1=plot(ax,nan,nan,'o','Color',C(1,:),'MarkerFaceColor','none','LineWidth',S.lineWidth);
h2=plot(ax,nan,nan,'s','Color',C(2,:),'MarkerFaceColor','none','LineWidth',S.lineWidth);
legend(ax,[h1 h2],{'Area sweep','Path-loss sweep'},'Location','northeast','FontSize',S.legendSize);
xlabel(ax,'Mean Tree hop count, E[H]'); ylabel(ax,'Estimated Tree p_f at PDR = 0.95'); grid(ax,'on'); box(ax,'on');
save_panel(fig,fullfile(outDir,'Fig03b_geometry_hop_boundary'),S);
