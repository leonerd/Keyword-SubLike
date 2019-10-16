#  You may distribute under the terms of either the GNU General Public License
#  or the Artistic License (the same terms as Perl itself)
#
#  (C) Paul Evans, 2019 -- leonerd@leonerd.org.uk

package Keyword::SubLike;

use strict;
use warnings;

our $VERSION = '0.01';

require XSLoader;
XSLoader::load( __PACKAGE__, $VERSION );

use Exporter 'import';
our @EXPORT = qw( sublike );

0x55AA;
