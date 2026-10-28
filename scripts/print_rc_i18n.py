"""Shared helper localization. No process remains resident during capture."""
import json
import os
from pathlib import Path

ROOT=Path(__file__).resolve().parent.parent
_CATALOGS={}
def language():
    value=os.environ.get('PRINT_RC_LANG','')
    if not value:
        path=ROOT/'config/language'
        if path.is_file() and not path.is_symlink() and not path.parent.is_symlink():
            value=path.read_text(encoding='utf-8')[:64].strip()
    if not value:
        value=next((os.environ[k] for k in ('LC_ALL','LC_MESSAGES','LANG') if os.environ.get(k)), 'en-US')
    value=value.lower().replace('_','-').split('.')[0]
    return 'pt-BR' if value=='pt' or value.startswith('pt-') else 'en-US'

def tr(key,*args):
    locale=language()
    if locale not in _CATALOGS:
        _CATALOGS[locale]=json.loads((ROOT/'i18n'/f'{locale}.json').read_text(encoding='utf-8'))
    return _CATALOGS[locale][key].format(*args)

def affirmative(value):return value.strip().casefold() in ('1','y','yes','s','sim')

def confirm(question):
    while True:
        try:answer=input(question+tr('common.confirm')).strip().casefold()
        except EOFError:return False
        if affirmative(answer):return True
        if answer in ('','2','n','no','nao','não'):return False
        print(tr('shell.answer_invalid'))


def localize_argparse():
    import argparse
    phrases={'usage: ':'cli.usage','positional arguments':'cli.positionals',
             'options':'cli.options','optional arguments':'cli.optional',
             'show this help message and exit':'cli.help',
             'the following arguments are required: %s':'cli.required',
             'unrecognized arguments: %s':'cli.unrecognized',
             '%(prog)s: error: %(message)s\n':'cli.error',
             'invalid choice: %(value)r (choose from %(choices)s)':'cli.invalid_choice'}
    argparse._=lambda message: tr(phrases[message]) if message in phrases else message
