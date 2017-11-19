window.deps = {
    'react' : require('react'),
    'react-dom' : require('react-dom'),
    'draft-js' : require('draft-js'),
    'SearchFieldEditor' : require ('./SearchFieldEditor'),
    'EntryTextEditor' : require ('./EntryTextEditor'),
    'BigCalendar' : require ('./bigCalendar')
};

window.React = window.deps['react'];
window.ReactDOM = window.deps['react-dom'];
window.Draft = window.deps['draft-js'];
window.ReactPerf = window.deps['react-addons-perf'];
window.MyEditor = window.deps['editor'];
