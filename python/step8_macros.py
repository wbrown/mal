import sys, traceback
import mal_readline
import mal_types as types
import reader, printer
from env import Env
import core

# read
def READ(str):
    return reader.read_str(str)

# eval
def is_pair(x):
    return types._sequential_Q(x) and len(x) > 0

def quasiquote(ast):
    if not is_pair(ast):
        return types._list(types._symbol("quote"),
                           ast)
    elif ast[0] == 'unquote':
        return ast[1]
    elif is_pair(ast[0]) and ast[0][0] == 'splice-unquote':
        return types._list(types._symbol("concat"),
                           ast[0][1],
                           quasiquote(ast[1:]))
    else:
        return types._list(types._symbol("cons"),
                           quasiquote(ast[0]),
                           quasiquote(ast[1:]))

def is_macro_call(ast, env):
    return (types._list_Q(ast) and
            types._symbol_Q(ast[0]) and
            env.find(ast[0]) and
            hasattr(env.get(ast[0]), '_ismacro_'))

def macroexpand(ast, env):
    while is_macro_call(ast, env):
        mac = env.get(ast[0])
        ast = macroexpand(mac(*ast[1:]), env)
    return ast

def eval_ast(ast, env):
    if types._symbol_Q(ast):
        return env.get(ast)
    elif types._list_Q(ast):
        return types._list(*map(lambda a: EVAL(a, env), ast))
    elif types._vector_Q(ast):
        return types._vector(*map(lambda a: EVAL(a, env), ast))
    elif types._hash_map_Q(ast):
        keyvals = []
        for k in ast.keys():
            keyvals.append(EVAL(k, env))
            keyvals.append(EVAL(ast[k], env))
        return types._hash_map(*keyvals)
    else:
        return ast  # primitive value, return unchanged

def EVAL(ast, env):
    while True:
        #print("EVAL %s" % ast)
        if not types._list_Q(ast):
            return eval_ast(ast, env)

        # apply list
        ast = macroexpand(ast, env)
        if not types._list_Q(ast): return ast
        if len(ast) == 0: return ast
        a0 = ast[0]

        if "def!" == a0:
            a1, a2 = ast[1], ast[2]
            res = EVAL(a2, env)
            return env.set(a1, res)
        elif "let*" == a0:
            a1, a2 = ast[1], ast[2]
            let_env = Env(env)
            for i in range(0, len(a1), 2):
                let_env.set(a1[i], EVAL(a1[i+1], let_env))
            return EVAL(a2, let_env)
        elif "quote" == a0:
            return ast[1]
        elif "quasiquote" == a0:
            return EVAL(quasiquote(ast[1]), env)
        elif 'defmacro!' == a0:
            func = EVAL(ast[2], env)
            func._ismacro_ = True
            return env.set(ast[1], func)
        elif 'macroexpand' == a0:
            return macroexpand(ast[1], env)
        elif "do" == a0:
            eval_ast(ast[1:-1], env)
            ast = ast[-1]
            # Continue loop (TCO)
        elif "if" == a0:
            a1, a2 = ast[1], ast[2]
            cond = EVAL(a1, env)
            if cond is None or cond is False:
                if len(ast) > 3: ast = ast[3]
                else:            ast = None
            else:
                ast = a2
            # Continue loop (TCO)
        elif "fn*" == a0:
            a1, a2 = ast[1], ast[2]
            return types._function(EVAL, Env, a2, env, a1)
        else:
            el = eval_ast(ast, env)
            f = el[0]
            if hasattr(f, '__ast__'):
                ast = f.__ast__
                env = f.__gen_env__(el[1:])
            else:
                return f(*el[1:])

# print
def PRINT(exp):
    return printer._pr_str(exp)

# repl
repl_env = Env()
def REP(str):
    return PRINT(EVAL(READ(str), repl_env))
def _ref(k,v): repl_env.set(k, v)

# Import types functions
for name, val in core.ns.items(): _ref(name, val)

_ref('read-string', reader.read_str)
_ref('eval', lambda ast: EVAL(ast, repl_env))
_ref('slurp', lambda file: open(file).read())

# Defined using the language itself
REP("(def! not (fn* (a) (if a false true)))")
REP("(def! load-file (fn* (f) (eval (read-string (str \"(do \" (slurp f) \")\")))))")

if len(sys.argv) >= 2:
    REP('(load-file "' + sys.argv[1] + '")')
else:
    while True:
        try:
            line = mal_readline.readline("user> ")
            if line == None: break
            if line == "": continue
            print(REP(line))
        except reader.Blank: continue
        except Exception as e:
            print "".join(traceback.format_exception(*sys.exc_info()))
