package mal;

import java.io.IOException;

import java.util.List;
import java.util.Map;
import java.util.HashMap;
import java.util.Iterator;
import mal.types.*;
import mal.readline;
import mal.reader;
import mal.printer;

public class step2_eval {
    // read
    public static MalVal READ(String str) throws MalThrowable {
        return reader.read_str(str);
    }

    // eval
    public static MalVal eval_ast(MalVal ast, HashMap env) throws MalThrowable {
        if (ast instanceof MalSymbol) {
            MalSymbol sym = (MalSymbol)ast;
            return (MalVal)env.get(sym.getName());
        } else if (ast instanceof MalList) {
            MalList old_lst = (MalList)ast;
            MalList new_lst = ast.list_Q() ? new MalList()
                                           : (MalList)new MalVector();
            for (MalVal mv : (List<MalVal>)old_lst.value) {
                new_lst.conj_BANG(EVAL(mv, env));
            }
            return new_lst;
        } else if (ast instanceof MalHashMap) {
            MalHashMap new_hm = new MalHashMap();
            Iterator it = ((MalHashMap)ast).value.entrySet().iterator();
            while (it.hasNext()) {
                Map.Entry entry = (Map.Entry)it.next();
                new_hm.value.put(entry.getKey(), EVAL((MalVal)entry.getValue(), env));
            }
            return new_hm;
        } else {
            return ast;
        }
    }

    public static MalVal EVAL(MalVal orig_ast, HashMap env) throws MalThrowable {
        MalVal a0;
        //System.out.println("EVAL: " + printer._pr_str(orig_ast, true));
        if (!orig_ast.list_Q()) {
            return eval_ast(orig_ast, env);
        }

        // apply list
        MalList ast = (MalList)orig_ast;
        if (ast.size() == 0) { return ast; }
        a0 = ast.nth(0);
        if (!(a0 instanceof MalSymbol)) {
            throw new MalError("attempt to apply on non-symbol '"
                    + printer._pr_str(a0,true) + "'");
        }
        MalVal args = eval_ast(ast.rest(), env);
        MalSymbol fsym = (MalSymbol)a0;
        ILambda f = (ILambda)env.get(fsym.getName());
        if (f == null) {
            throw new MalError("'" + fsym.getName() + "' not found");
        }
        return f.apply((MalList)args);
    }

    // print
    public static String PRINT(MalVal exp) {
        return printer._pr_str(exp, true);
    }

    // REPL
    public static MalVal RE(HashMap env, String str) throws MalThrowable {
        return EVAL(READ(str), env);
    }

    static interface ILambda {
        public MalVal apply(MalList args);
    }
    static class plus implements ILambda {
        public MalVal apply(MalList args) {
            return ((MalInteger)args.nth(0)).add(
                    ((MalInteger)args.nth(1)));
        }
    }
    static class minus implements ILambda {
        public MalVal apply(MalList args) {
            return ((MalInteger)args.nth(0)).subtract(
                    ((MalInteger)args.nth(1)));
        }
    }
    static class multiply implements ILambda {
        public MalVal apply(MalList args) {
            return ((MalInteger)args.nth(0)).multiply(
                    ((MalInteger)args.nth(1)));
        }
    }
    static class divide implements ILambda {
        public MalVal apply(MalList args) {
            return ((MalInteger)args.nth(0)).divide(
                    ((MalInteger)args.nth(1)));
        }
    }

    public static void main(String[] args) throws MalThrowable {
        String prompt = "user> ";

        HashMap repl_env = new HashMap();
        repl_env.put("+", new plus());
        repl_env.put("-", new minus());
        repl_env.put("*", new multiply());
        repl_env.put("/", new divide());

        if (args.length > 0 && args[0].equals("--raw")) {
            readline.mode = readline.Mode.JAVA;
        }
        while (true) {
            String line;
            try {
                line = readline.readline(prompt);
                if (line == null) { continue; }
            } catch (readline.EOFException e) {
                break;
            } catch (IOException e) {
                System.out.println("IOException: " + e.getMessage());
                break;
            }
            try {
                System.out.println(PRINT(RE(repl_env, line)));
            } catch (MalContinue e) {
                continue;
            } catch (MalError e) {
                System.out.println("Error: " + e.getMessage());
                continue;
            } catch (reader.ParseError e) {
                System.out.println(e.getMessage());
                continue;
            }
        }
    }
}
