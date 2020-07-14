% SP_BSPLINE_1D_PARAM: Construct a space of B-Splines on the parametric domain in 1D.
%                      This function is not usually meant to be invoked directly by the user but rather
%                      through sp_bspline.
%
%     sp = sp_bspline_1d_param (knots, degree, nodes, 'option1', value1, ...)
%
% INPUTS:
%     
%     knots:  open knot vector    
%     degree: b-spline polynomial degree
%     nodes:  points in the parametric domain at which to evaluate, 
%             i.e. quadrature points or points for visualization  
%    'option', value: additional optional parameters, currently available options are:
%            
%              Name     |   Default value |  Meaning
%           ------------+-----------------+-----------------------------------
%            gradient   |      true       |  compute shape_function_gradients
%            hessian    |     false       |  compute shape_function_hessians
%
% OUTPUT:
%
%    sp: structure representing the function space, see the technical report
%        for a detailed description
%
% 
% Copyright (C) 2009, 2010 Carlo de Falco
%
%    This program is free software: you can redistribute it and/or modify
%    it under the terms of the GNU General Public License as published by
%    the Free Software Foundation, either version 3 of the License, or
%    (at your option) any later version.

%    This program is distributed in the hope that it will be useful,
%    but WITHOUT ANY WARRANTY; without even the implied warranty of
%    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%    GNU General Public License for more details.
%
%    You should have received a copy of the GNU General Public License
%    along with this program.  If not, see <http://www.gnu.org/licenses/>.

function sp = sp_bspline_1d_param (knots, degree, nodes, varargin)

gradient = true; 
hessian  = false; 
periodic = false;
regularity = degree-1;

if (~isempty (varargin))
  if (~rem (length (varargin), 2) == 0)
    error ('sp_bspline_1d_param: options must be passed in the [option, value] format');
  end
  for ii=1:2:length(varargin)-1
    if (strcmpi (varargin {ii}, 'gradient'))
      gradient = varargin {ii+1};
    elseif (strcmpi (varargin {ii}, 'hessian'))
      hessian = varargin {ii+1};
    elseif (strcmpi (varargin {ii}, 'periodic'))
      periodic = varargin{ii+1};
    elseif (strcmpi (varargin {ii}, 'regularity'))
      regularity = varargin{ii+1};
    else 
      error ('sp_bspline_1d_param: unknown option %s', varargin {ii});
    end
  end
end

if (hessian)
  nders=2;
elseif (gradient)
  nders=1;
else
  nders=0;
end

mknots = length (knots)-1;
p      = degree;
mcp    = -p - 1 + mknots;
ndof   = mcp + 1;

nel = size (nodes, 2);
nqn = size (nodes, 1);

nsh = zeros (1, nel);
connectivity = zeros (p+1, nel);
for iel=1:nel
  s = findspan (mcp, p, nodes(:, iel)', knots);
  c = numbasisfun (s, nodes(:, iel)', p, knots);
  c = unique(c(:))+1;
  connectivity(1:numel(c), iel) = c;
  nsh(iel) = nnz (connectivity(:,iel));
end

nsh_max = max (nsh);

s     = findspan(mcp, p, nodes, knots);
tders = basisfunder (s, p, nodes, knots, nders);
nbf   = numbasisfun (s(:)', nodes(:)', p, knots);
nbf   = reshape (nbf+1, size(s,1), size(s,2), p+1);

ders = zeros (numel(nodes), nders+1, nsh_max);
for inqn = 1:numel(nodes)
  [ir,iel] = ind2sub (size(nodes),inqn);
  ind = find (connectivity(:,iel) == nbf(ir,iel,1)); 
  ders(inqn,:,ind:ind+p) = tders(inqn,:,:);
end

supp = cell (ndof, 1);
for ii = 1:ndof
  [~, supp{ii}] = find (connectivity == ii);
end

shape_functions = reshape (ders(:, 1, :), nqn, nel, []);
shape_functions = permute (shape_functions, [1, 3, 2]);

if (periodic)
  n_extra_dofs = regularity+1;

  ndof = ndof-n_extra_dofs;
  nsh  = repmat(nsh_max,1,size(connectivity,2));

  connectivity = mod(connectivity-1,ndof)+1;

  for k = 1:n_extra_dofs
    supp{n_extra_dofs-k+1} = [supp{end}; supp{n_extra_dofs-k+1}];
    supp(end) = []; % deletes cell-array element!
  end
end

sp = struct ('nsh_max', nsh_max, 'nsh', nsh, 'ndof', ndof,  ...
             'connectivity', connectivity, ...
             'shape_functions', shape_functions, ...
             'ncomp', 1, 'degree', degree, 'knots', knots);
sp.supp = supp;

if (gradient)
  shape_function_gradients = reshape (ders(:, 2, :), nqn, nel, []);
  shape_function_gradients = permute (shape_function_gradients, [1, 3, 2]);
  sp.('shape_function_gradients') = shape_function_gradients;
end

if (hessian)
  shape_function_hessians = reshape (ders(:, 3, :), nqn, nel, []);
  shape_function_hessians = permute (shape_function_hessians, [1, 3, 2]);
  sp.('shape_function_hessians') = shape_function_hessians;
end


end


%!test
%! knots = [0 0 0 .5 1 1 1];
%! degree = 2;
%! points = [0 .1 .2; .6 .7 .8]';
%! sp = sp_bspline_1d_param (knots, degree, points, 'hessian', true);
%! assert (sp.ndof, 4)
%! assert (sp.nsh_max,  3)
%! assert (sp.connectivity,  [1 2 3; 2 3 4].')
