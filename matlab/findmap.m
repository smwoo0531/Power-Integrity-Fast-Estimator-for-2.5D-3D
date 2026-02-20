% Create 2D array based on chip mesh size to show the location of the
% chiplets in the 2nd tier
function tiermap = findmap(system,chip,i)

    % i is holding the # of chips in the BEOL of chip 1
    %i = 1;
    %i = 2;
    %i = 4;
    %i = 6;
    % Need to change this so it works for all tiers...
    %i = chip(1).blk_num(2);

    % Create map of 0's to hold locations
    map = zeros(length(chip(1).Ymesh), length(chip(1).Xmesh));

    % Let chiplet be half the size of the tier1 chip in this example
    if i == 1
        chip2XSize = system.embeddedchip*(chip(1).Xsize);
        chip2YSize = system.embeddedchip*(chip(1).Ysize);
    elseif i==2
        chip2XSize = system.embeddedchip*(chip(1).Xsize/2);
        chip2YSize = (chip(1).Ysize)/2;
    % More than 2 chips
    else
        chip2XSize = system.embeddedchip*(chip(1).Xsize)/(i/2);
        chip2YSize = system.embeddedchip*(chip(1).Ysize)/2;
    end

    % Single chip in BEOL - assume to be half the size of top die
    if i == 1
        % Get positioning of chiplet centered with tier1
        startX = (chip(1).Xsize - chip2XSize)/2;
        startY = (chip(1).Ysize - chip2YSize)/2;
        endX = startX + chip2XSize;
        endY = startY + chip2YSize;
    
        % Find in reference to the array
        [~, x1] = min(abs(chip(1).Xmesh - startX));
        [~,x2] = min(abs(chip(1).Xmesh - endX));
        [~,y1] = min(abs(chip(1).Ymesh - startY));
        [~,y2] = min(abs(chip(1).Ymesh - endY));
    
        map(y1:y2,x1:x2) = 1;
        tiermap = map;
    else
       
        tempX = chip2XSize*2;
        tempY = chip2YSize*2;

        if i == 2
            for j = 1:2
                %Get positioning of chiplet centered with tier1
                startX = (tempX - chip2XSize)/2 + tempX*(j-1);
                startY = (chip(1).Ysize - chip2YSize)/2;
                endX = startX + chip2XSize;
                endY = startY + chip2YSize;

                %fprintf('\n%d %d %d %d\n', startX,startY,endX,endY)
    
                %Find in reference to the array
                [~, x1] = min(abs(chip(1).Xmesh - startX));
                [~,x2] = min(abs(chip(1).Xmesh - endX));
                [~,y1] = min(abs(chip(1).Ymesh - startY));
                [~,y2] = min(abs(chip(1).Ymesh - endY));
    
                map(y1:y2,x1:x2) = 1;
            end
        else
            for j = 1:2
                for k = 1:(i/2)

                    %Get positioning of chiplet centered with tier1
                    startX = (tempX - chip2XSize)/2 + tempX*(k-1);
                    startY = (tempY - chip2YSize)/2 + tempY*(j-1);
                    endX = startX + chip2XSize;
                    endY = startY + chip2YSize;

                    %fprintf('\n%d %d %d %d\n', startX,startY,endX,endY)

                    %Find in reference to the array
                    [~, x1] = min(abs(chip(1).Xmesh - startX));
                    [~,x2] = min(abs(chip(1).Xmesh - endX));
                    [~,y1] = min(abs(chip(1).Ymesh - startY));
                    [~,y2] = min(abs(chip(1).Ymesh - endY));

                    map(y1:y2,x1:x2) = 1;
                end
            end
        end
        tiermap = map;
    end

end

%map = zeros(10, 10);
%map(2:9,2:9) = 5

