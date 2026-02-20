function [ L, U, P,Q,R ] = tranFac(Y, C, r, FLAG)
    spparms('spumoni', 0);
    if FLAG == 1
        A = C/r+Y/2;
    else
        A = C/r+Y;
    end
    tic;
    [L,U,P,Q,R] = lu(A);
    fprintf('factorization done, using %.2 seconds\n', toc);
end