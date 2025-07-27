#import "../src/lib.typ": backrefs
#set page(width: auto, height: auto)

#show: backrefs

@test

#bibliography(bytes("
  @article{test,
    title = {Test}
  }
"))
