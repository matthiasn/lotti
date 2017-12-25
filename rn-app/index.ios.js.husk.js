RE_NATAL_PLACEHOLDER(function (name) {
    var modules=require('./husk-requires');
    if (modules[name]){
        return modules[name];
    }
    else {
        console.error("Not found:", name);
    }
});
