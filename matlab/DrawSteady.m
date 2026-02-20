function [MaxT, MinT] = DrawSteady(index, Xmesh, Ymesh, drawT_die, map, name, system)
    MinT = min(min(drawT_die));
    MaxT = max(max(drawT_die));
    figure(index);
    if isempty(drawT_die) ~= 1
        contourf(Xmesh*100, Ymesh*100, abs(drawT_die)*1000, 30, 'Linestyle','none');
        hold on;
    end
    
    len = size(map, 1);
    for i=1:len      
        xl = map(i,1);
        width = map(i,3);
        yb = map(i,2);
        height = map(i,4);
        if strcmp(char(name(i)), 'bridge') == 1
            rectangle('Position',[xl yb width height]*100, 'LineWidth', 1.5, 'edgecolor', 'r', 'LineStyle', '--');
            name(i) = cellstr('');
        else
            rectangle('Position',[xl yb width height]*100, 'LineWidth', 1);
        end
        if isempty(char(name(i))) == 0              
            text((xl+width/2)*100, (yb+height/2)*100, char(name(i)), 'HorizontalAlignment','center', 'FontSize', 14, 'FontWeight', 'Bold')
        end
        hold on;
    end

    if system.clamp == 1 && isempty(drawT_die) ~= 1
        caxis([system.range(1), system.range(2)]);
    end    

    axis off;
    axis equal;
    if isempty(drawT_die) ~= 1
        h=colorbar;
        set(get(h,'Title'),'string','Noise(mV)','FontSize',16);
    end
    set(gca,'FontSize',16);
    xlabel('x(cm)');
    ylabel('y(cm)');set(gca,'FontSize',16);
end