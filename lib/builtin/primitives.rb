# Functions that create other functions

# (define) binds values to names in the current scope.
# If the first parameter is a list it creates a function,
# otherwise it eval's the second parameter and binds it
# to the name given by the first.
metadef('define') do |scope, names, *body|
  List === names ?
      scope.define(names.first, names.rest, List.from(body)) :
      scope[names] = Heist.value_of(body.first, scope)
  nil
end

# (lambda) returns an anonymous function whose arguments
# are named by the first parameter and whose body is given
# by the remaining parameters.
metadef('lambda') do |scope, names, *body|
  Function.new(scope, names, List.from(body))
end

# (set!) reassigns the value of an existing bound variable,
# in the innermost scope responsible for binding it.
metadef('set!') do |scope, name, value|
  scope.set!(name, Heist.value_of(value, scope))
  nil
end

#----------------------------------------------------------------

# Macros

metadef('define-syntax') do |scope, name, transformer|
  scope[name] = Heist.value_of(transformer, scope)
end

metadef('let-syntax') do |*args|
  call('let', *args)
end

metadef('letrec-syntax') do |*args|
  call('letrec', *args)
end

metadef('syntax-rules') do |scope, keywords, *rules|
  Macro.new(scope, keywords, rules)
end

#----------------------------------------------------------------

# Continuations

metadef('call-with-current-continuation') do |scope, callback|
  continuation = Continuation.new(scope.runtime.stack)
  callback = Heist.value_of(callback, scope)
  callback.call(scope, [continuation])
end

#----------------------------------------------------------------

# Quoting functions

# (quote) casts identifiers to symbols. If given a list, it
# quotes all items in the list recursively.
metadef('quote') do |scope, arg|
  case arg
  when List then arg.map { |cell| call('quote', scope, cell) }
  when Identifier then arg.to_s.to_sym
  else arg
  end
end

#----------------------------------------------------------------

# Control structures

# (begin) simply executes a series of lists in the current scope.
metadef('begin') do |scope, *body|
  Body.new(body, scope)
end

# (cond) acts like the 'switch' statement in C-style languages.
# Once a matching precondition is found, its consequent is
# tail-called and no further preconditions are evaluated.
metadef('cond') do |scope, *pairs|
  result = nil
  pairs.each do |list|
    next if result
    next unless Heist.value_of(list.first, scope)
    result = Body.new(list[1..-1], scope)
  end
  result
end

# 'else' should really only be used inside (cond) blocks.
define('else') { true }

# (if) evaluates the consequent if the condition eval's to
# true, otherwise it evaluates the alternative
metadef('if') do |scope, cond, cons, alt|
  which = Heist.value_of(cond, scope) ? cons : alt
  Frame.new(which, scope)
end

#----------------------------------------------------------------

# Boolean combinators

# (and) evaluates its arguments until one of them returns
# false. Returns true iff all arguments eval to true.
metadef('and') do |scope, *args|
  result = true
  args.each do |arg|
    next if !result
    result = Heist.value_of(arg, scope)
  end
  result
end

# (or) evaluates its arguments until one of them returns
# true. Returns false iff all arguments eval to false.
metadef('or') do |scope, *args|
  result = false
  args.each do |arg|
    next if result
    result = Heist.value_of(arg, scope)
  end
  result
end

#----------------------------------------------------------------

# Runtime utilities

define('exit') { exit }

metadef('runtime') do |scope|
  scope.runtime.elapsed_time
end

metadef('eval') do |scope, string|
  scope.eval(Heist.value_of(string, scope))
end

define('display') do |expression|
  puts expression
end

metadef('load') do |scope, file|
  scope.load(file)
end

#----------------------------------------------------------------

# Arithmetic and other math functions

define('+') do |*args|
  args.any? { |arg| String === arg } ?
      args.inject("") { |str, arg| str + arg.to_s } :
      args.inject(0)  { |sum, arg| sum + arg }
end

define('-') do |op1, op2|
  op2.nil? ? 0 - op1 : op1 - op2
end

define('*') do |*args|
  args.inject(1) { |prod, arg| prod * arg }
end

define('/') do |op1, op2|
  op2.nil? ? 1.0 / op1 : op1 / op2.to_f
end

define('expt') do |op1, op2|
  op1 ** op2
end

define('remainder') do |op1, op2|
  op1 % op2
end

define('random') do |max|
  rand(max)
end

define('max') do |*args|
  args.max
end

define('min') do |*args|
  args.min
end

#----------------------------------------------------------------

# Comparators

define('eqv?') do |op1, op2|
  op1.class == op2.class && op1 == op2
end

define('=') do |op1, op2|
  # TODO raise an exception if they're not numeric
  Numeric === op1 && Numeric === op2 && op1 == op2
end

define('>') do |op1, op2|
  op1 > op2
end

define('<') do |op1, op2|
  op1 < op2
end

#----------------------------------------------------------------

# Type-checking predicates

define('complex?') do |value|
  call('real?', value) # || TODO
end

define('real?') do |value|
  call('rational?', value) || Float === value
end

define('rational?') do |value|
  call('integer?', value) || Float === value # TODO handle this properly
end

define('integer?') do |value|
  Integer === value
end
