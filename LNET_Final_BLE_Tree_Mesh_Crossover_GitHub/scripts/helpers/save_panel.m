function save_panel(fig,base,S)
set(fig,'PaperUnits','inches','PaperPosition',[0 0 S.figWidth S.figHeight], ...
    'PaperSize',[S.figWidth S.figHeight],'InvertHardcopy','off');
print(fig,[base '.pdf'],'-dpdf','-painters');
print(fig,[base '.png'],'-dpng','-r300');
if S.saveFig
    savefig(fig,[base '.fig'],'-v7');
end
end
