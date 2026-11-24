function [fig,ax] = make_panel(S)
fig = figure('Color','w','Units','inches','Position',[1 1 S.figWidth S.figHeight]);
ax = axes(fig,'Position',S.axesPosition);
set(ax,'FontName',S.fontName,'FontSize',S.fontSize,'LineWidth',S.axesLineWidth);
end
