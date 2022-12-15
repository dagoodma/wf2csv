from __future__ import (
    absolute_import, division, print_function, unicode_literals)

from operator import itemgetter

mapping = {
    'has_header': False,
    'is_split': False,
    'currency': 'USD',
    'delimiter': ',',
    'account': "Wells Fargo Credit Card",
    'date': itemgetter('column_1'),
    'type': 'visa',
    'amount': itemgetter('column_2'),
    #'type': lambda tr: 'DEBIT' if tr.get('Amount') > 0 else 'CREDIT',
    'desc': itemgetter('column_5'),
    'payee': itemgetter('column_5'),
}
