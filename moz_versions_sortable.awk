# mozilla firefox version numbers

function v2num (v) {
    return v*1000000;
}

/^[[:digit:]]+\.[[:digit:]]+b[[:digit:]]+$/ {
    # beta versions
    split($0,parts,"b");
    print v2num(parts[1])+parts[2] "\t" $0;    
}

/^[[:digit:]]+\.[[:digit:]]+$/ {
    # releases
    print v2num($0)+1000 "\t" $0;
    
}
