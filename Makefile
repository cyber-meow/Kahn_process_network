OCAMLBUILD=ocamlbuild -classic-display \
                      -pkgs lwt,lwt.unix,unix,str,graphics
TARGET=native
DIR=use_examples/

k_means:
	$(OCAMLBUILD) $(DIR)k_means.$(TARGET)

put_get:
	$(OCAMLBUILD) $(DIR)put_get_test.$(TARGET)

int_printer:
	$(OCAMLBUILD) $(DIR)int_printer.$(TARGET)

alter_print:
	$(OCAMLBUILD) $(DIR)alter_print.$(TARGET)

prime_sieve:
	$(OCAMLBUILD) $(DIR)sieve_Eratosthenes.$(TARGET)

mandelbrot:
	$(OCAMLBUILD) $(DIR)Mandelbrot.$(TARGET)

pong:
	$(OCAMLBUILD) $(DIR)pong_dist.$(TARGET)

int_printer_net:
	$(OCAMLBUILD) $(DIR)int_printer_network.$(TARGET)

prime_sieve_net:
	$(OCAMLBUILD) $(DIR)sieve_Eratosthenes_network.$(TARGET)



clean:
	$(OCAMLBUILD) -clean

realclean: clean
	rm -f *~

cleanall: realclean
