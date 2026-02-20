% Create 2D array based on chip mesh size to show the location of the
% chiplets in the 2nd tier
function tiermap = findmap(system,chip)

    % Create map of 0's to hold locations
    map = ones(length(chip(1).Ymesh), length(chip(1).Xmesh));
    chip2XSize = 0.0203;
    chip2YSize = 0.0203;


    % Single chip in BEOL - assume to be half the size of top die
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
        % 
        % [~, x1] = min(abs(chip(1).Xmesh - chip(1).tsv_map(1)));
        % [~,x2] = min(abs(chip(1).Xmesh - chip(1).tsv_map(3)));
        % [~,y1] = min(abs(chip(1).Ymesh - chip(1).tsv_map(2)));
        % [~,y2] = min(abs(chip(1).Ymesh - chip(1).tsv_map(4)));

        
        map(y1:y2,x1:x2) = 0;

        tiermap = map;

%map = zeros(10, 10);
%map(2:9,2:9) = 5

