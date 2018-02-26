LIB = x.load

jessym.o: jessym.s
	as --goff -o $@ $<

jessym: jessym.o
	ld -o $@ $<
	cp -X $@ ${LIB}

clean:
	rm -f *.o jessym