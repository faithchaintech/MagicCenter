#include <assert.h>
#include <stdio.h>
#include "Gesture.h"
int main(void) {
    Gesture g={.enabled=true,.width=.24};
    assert(convert(&g,0,0,1,.5,.01,false));
    assert(g.clicks==1);
    assert(convert(&g,1,0,0,0,100,true)); // Drag remains paired outside strip.
    assert(!convert(&g,2,1,0,0,100,false)); // Other button cannot release it.
    g.enabled=false;
    assert(convert(&g,2,0,0,0,100,false)); // Pausing must still release.
    assert(!g.dragging);
    assert(!convert(&g,0,0,1,.5,.01,false));
    g.enabled=true;
    assert(!convert(&g,0,0,2,.5,.01,false));
    assert(!convert(&g,0,0,0,.5,.01,false));
    assert(!convert(&g,0,0,1,.2,.01,false));
    assert(!convert(&g,0,0,1,.8,.01,false));
    assert(!convert(&g,0,0,1,.5,.21,false));
    assert(!convert(&g,0,0,1,.5,-1,false));
    assert(!convert(&g,0,0,1,NAN,.01,false));
    assert(!convert(&g,0,0,1,.5,.01,true));
    assert(!convert(&g,1,0,1,.5,.01,false));
    assert(!convert(&g,2,0,1,.5,.01,false));
    assert(convert(&g,0,1,1,.5,.01,false)); // Center may arrive as a secondary click.
    assert(convert(&g,2,1,1,.5,.01,false));
    assert(g.clicks==2);
    puts("Passed: center/edge classification, stale frames, multitouch/trackpad rejection, right-button mapping, drag/release pairing, pause during drag.");
}
