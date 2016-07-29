function result = smooth(M)
    [m,~] = size(M);
    result = zeros(size(M));
    for i = 1:m
        if i == 1
            result(i,:) = M(i+1,:)-M(i,:);
        elseif i == m
            result(i,:) = M(i,:)-M(i-1,:);
        else
            result(i,:) = (M(i+1,:)-M(i-1,:))/2;
        end
    end
end
        