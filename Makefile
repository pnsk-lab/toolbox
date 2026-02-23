PC = fpc
PCFLAGS =

.PHONY: all clean

all: crawl/crawl$(E) server/crawlserver$(E)

crawl/crawl$(E): crawl/*.pas
	fpc -Mobjfpc -Sh $(PCFLAGS) -e$@ crawl/crawl.pas

server/crawlserver$(E): server/*.pas
	@echo "$(PCFLAGS)" | grep -- "-dDATABASE" >/dev/null 2>&1 ; if [ "$$?" = "0" ]; then fpc -Mobjfpc -Sh $(PCFLAGS) -e$@ server/crawlserver.pas ; fi

clean:
	rm -f */*.ppu */*.o */*.exe crawl/crawl server/crawlserver
