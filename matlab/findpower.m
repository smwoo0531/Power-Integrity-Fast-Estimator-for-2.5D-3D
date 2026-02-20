% Create die2_map, assuming uniform power. Divide total power by # of
% chiplets embedded in tier2
function power = findpower(system,chip, totalpower, i)

    % i is holding the # of chips in the BEOL of chip 1
    %i = 1;
    %i = 2;
    %i = 4;
    %i = 6;
    %i = chip(1).blk_num(2);
    power = zeros(i,6);


    % Create map of 0's to hold locations
    %map = zeros(length(chip(1).Ymesh), length(chip(1).Xmesh));

    % Let chiplet be half the size of the tier1 chip in this example
    if i == 1
        chip2XSize = system.embeddedchip*(chip(1).Xsize);
        chip2YSize = system.embeddedchip*(chip(1).Ysize);
    elseif i==2
        chip2XSize = system.embeddedchip*(chip(1).Xsize)/2;
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
    
        power(1) = startX;
        power(2) = startY;
        power(3) = chip2XSize;
        power(4) = chip2YSize;
        power(5) = totalpower/i;
    else
       
        tempX = chip2XSize*2;
        tempY = chip2YSize*2;

        if i == 2
            for j = 1:2
                %Get positioning of chiplet centered with tier1
                startX = (tempX - chip2XSize)/2 + tempX*(j-1);
                startY = (chip(1).Ysize - chip2YSize)/2;

                power(j,1) = startX;
                power(j,2) = startY;
                power(j,3) = chip2XSize;
                power(j,4) = chip2YSize;
                power(j,5) = totalpower/i;
            end
        else
            count = 1;
            for j = 1:2
                for k = 1:(i/2)

                    %Get positioning of chiplet centered with tier1
                    startX = (tempX - chip2XSize)/2 + tempX*(k-1);
                    startY = (tempY - chip2YSize)/2 + tempY*(j-1);

                    power(count,1) = startX;
                    power(count,2) = startY;
                    power(count,3) = chip2XSize;
                    power(count,4) = chip2YSize;
                    power(count,5) = totalpower/i;
                    % Update positioning
                    count = count + 1;
                end
            end
        end
    end

end

