"""File Control Manager: Windows terminal-based file and ACL utility."""
import argparse
import ctypes
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
from datetime import datetime

VERSION=(Path(__file__).parent/'VERSION').read_text(encoding='utf-8').strip()
DATA=Path(os.environ.get('LOCALAPPDATA',str(Path.home())))/'FileControlManager'
LOG=DATA/'activity.jsonl'
COLOR=sys.stdout.isatty() and not bool(os.environ.get('NO_COLOR'))
COLORS={'header':'\x1b[96m','menu':'\x1b[94m','error':'\x1b[91m','warning':'\x1b[93m','success':'\x1b[92m','dim':'\x1b[90m'}
def icon(emoji,symbol,ascii):
    if not sys.stdout.isatty() or os.environ.get('FCM_ICONS')=='ascii':return ascii
    if os.environ.get('WT_SESSION') or os.environ.get('TERM_PROGRAM'):return emoji
    return symbol

def colored(message,kind):
    return COLORS[kind]+message+'\x1b[0m' if COLOR else message

def administrator():
    try:return bool(ctypes.windll.shell32.IsUserAnAdmin())
    except (OSError,AttributeError):return False

def safe_path(value,destructive=True):
    if not value or not value.strip():raise ValueError('Specify a file or folder')
    p=Path(value.strip().strip('"')).absolute()
    if not p.exists() and not p.is_symlink():raise FileNotFoundError(str(p))
    if destructive:
        protected=[p.anchor,os.environ.get('WINDIR'),os.environ.get('ProgramFiles'),os.environ.get('ProgramData'),str(Path.home()),str(Path(__file__).parent)]
        if any(s and os.path.normcase(str(p))==os.path.normcase(str(Path(s).absolute())) for s in protected):raise ValueError('Protected root path')
        if p.is_symlink():raise ValueError('Symbolic links require manual review')
        if p.is_dir() and getattr(p.stat(),'st_file_attributes',0)&0x400:raise ValueError('Reparse-point directory is protected')
    return p

def record(action,path,success=True,detail=''):
    DATA.mkdir(parents=True,exist_ok=True)
    with LOG.open('a',encoding='utf-8') as stream:
        stream.write(json.dumps({'time':datetime.now().astimezone().isoformat(),'action':action,'path':str(path),'success':success,'detail':str(detail)},ensure_ascii=False)+'\n')

def command(args):
    result=subprocess.run(args,capture_output=True,text=True,errors='replace',shell=False)
    output=((result.stdout or '')+'\n'+(result.stderr or '')).strip()
    if result.returncode:raise RuntimeError(output or 'Command failed')
    return output

def confirm(label,path,delete=False):
    print(colored('\n  '+label+': '+str(path),'warning'))
    return input('  Type DELETE to permanently remove: ' if delete else '  Continue? [y/N]: ').strip()==('DELETE' if delete else 'y')

def inspect(p):
    info=p.stat()
    print('  Path:',p,'\n  Type:', 'Folder' if p.is_dir() else 'File','\n  Size:',info.st_size,'bytes')
    print('  Modified:',datetime.fromtimestamp(info.st_mtime))
    for args in (['icacls',str(p)],['cipher','/c',str(p)]):
        try:print(command(args))
        except (OSError,RuntimeError) as error:print('  Diagnostic:',error)

def rename(p):
    name=input('  New filename: ').strip()
    if not name or name in ('.','..') or name.endswith(('.',' ')) or any(c in name for c in '<>:"/\\|?*'):
        raise ValueError('Invalid Windows filename')
    target=p.with_name(name)
    if target.exists():raise FileExistsError(str(target))
    if confirm('Rename to',target):
        p.rename(target);record('rename',p,detail=str(target));return target
    return p

def transfer(p,move=False):
    folder=Path(input('  Existing destination directory: ').strip().strip('"')).absolute()
    if not folder.is_dir():raise NotADirectoryError(str(folder))
    destination=folder/p.name
    if destination.exists():raise FileExistsError(str(destination))
    if p.is_dir() and (p==folder or p in folder.parents):raise ValueError('Cannot move a directory into itself')
    if confirm('Move to' if move else 'Copy to',destination):
        if move:shutil.move(str(p),str(destination))
        elif p.is_dir():shutil.copytree(p,destination,symlinks=True)
        else:shutil.copy2(p,destination)
        record('move' if move else 'copy',p,detail=str(destination))
        return destination if move else p
    return p

def delete(p):
    if confirm('Permanent recursive deletion',p,delete=True):
        if p.is_dir():shutil.rmtree(p)
        else:p.unlink()
        record('delete',p)
        return None
    return p

def ownership(p):
    if not administrator():raise PermissionError('Administrator privileges required')
    if confirm('Take ownership recursively',p):
        args=['takeown','/F',str(p)]
        if p.is_dir():args+=['/R','/D','Y']
        print(command(args));record('ownership',p)

def grant(p):
    if not administrator():raise PermissionError('Administrator privileges required')
    if confirm('Grant Administrators Full Control',p):
        permissions='*S-1-5-32-544:(OI)(CI)F' if p.is_dir() else '*S-1-5-32-544:F'
        args=['icacls',str(p),'/grant',permissions]
        if p.is_dir():args+=['/T']
        print(command(args));record('grant',p)

def elevated():
    script=Path(__file__).parent/'FCM.ps1'
    args='-NoLogo -NoProfile -ExecutionPolicy Bypass -File "'+str(script)+'"'
    result=ctypes.windll.shell32.ShellExecuteW(None,'runas','powershell.exe',args,str(script.parent),1)
    if result<=32:raise OSError('Windows elevation denied')
    print('  Administrator session requested')

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--path',default='')
    parser.add_argument('--version',action='store_true')
    flags=parser.parse_args()
    if flags.version:print(VERSION);return 0
    if os.name!='nt':raise OSError('Windows only')
    selected=flags.path
    menu=['Choose file or folder','Inspect metadata, ACL and EFS status','Rename','Copy','Move','Permanently delete','Take ownership','Grant Administrators Full Control','Relaunch as Administrator','View logs','Exit']
    if os.name=='nt':
        os.system('')  # Enables virtual terminal processing in supported Windows consoles.
    while True:
        os.system('cls')
        print(colored('╔'+'═'*68+'╗','header'))
        print(colored('║  '+icon('🗂','◆','*')+'  FILE CONTROL MANAGER  |  FILES • FOLDERS • SECURITY       ║','header'))
        print(colored('╚'+'═'*68+'╝','header'))
        print(colored(f'  VERSION v{VERSION}   |   MODE '+('ADMINISTRATOR' if administrator() else 'STANDARD USER'),'success' if administrator() else 'warning'))
        print('  TARGET:',selected or '(not selected)')
        print('  '+'─'*66)
        glyphs=[('📁','■','>'),('🔎','●','?'),('✏','►','~'),('📋','■','+'),('📦','►','>'),('🗑','×','X'),('🔑','♦','*'),('🛡','√','+'),('🚀','▲','^'),('📜','■','#'),('🚪','◄','<')]
        for number,item in enumerate(menu,1):
            emoji,symbol,ascii=glyphs[number-1]
            print(colored(f'  {number:02d}  ','menu')+icon(emoji,symbol,ascii)+'  '+item)
        print(colored('  '+'─'*66,'dim'))
        print(colored('  Tip: choose a number • confirm destructive actions • Ctrl+C exits','dim'))
        choice=input('\n  Select [01-11]: ').strip()
        # The UI displays zero-padded numbers; accept both '01' and '1'.
        if choice.isascii() and choice.isdecimal():
            choice=str(int(choice))
        if choice=='11':return 0
        try:
            if choice=='1':selected=str(safe_path(input('  Path: '),destructive=False))
            elif choice=='9':elevated()
            elif choice=='10':
                print('  Log file:',LOG)
                if LOG.exists():print('\n'.join(LOG.read_text(encoding='utf-8').splitlines()[-15:]))
            elif choice in ('2','3','4','5','6','7','8'):
                p=safe_path(selected,destructive=choice!='2')
                if choice=='2':inspect(p)
                elif choice=='3':selected=str(rename(p))
                elif choice=='4':transfer(p)
                elif choice=='5':selected=str(transfer(p,move=True))
                elif choice=='6':selected=str(delete(p) or '')
                elif choice=='7':ownership(p)
                elif choice=='8':grant(p)
            else:print('  Unknown option')
        except (OSError,ValueError,RuntimeError) as error:
            print(colored('  ERROR: '+str(error),'error'))
            try:record('error',selected,False,error)
            except OSError:pass
        input('\n  Press Enter to continue...')

if __name__=='__main__':sys.exit(main())
