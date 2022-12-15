from __future__ import (
    absolute_import, division, print_function, unicode_literals)

from operator import itemgetter

mapping = {
    'has_header': True,
    'is_split': False,
    'bank': 'San Francisco Federal Credit Union',
    'currency': 'USD',
    'delimiter': ',',
    'account': itemgetter('Account Number'),
    'date': itemgetter('Post Date'),
    'type': lambda tr: 'DEBIT' if tr.get('Debit') else 'CREDIT',
    'amount': lambda tr: tr.get('Debit') or tr.get('Credit'),
    #'balance': itemgetter('Balance'),
    'desc': itemgetter('Description'),
    'payee': itemgetter('Description'),
    #'notes': itemgetter('Field'),
    #'class': itemgetter('Field'),
    #'id': itemgetter('Field'),
    'check_num': itemgetter('Check'),
}
