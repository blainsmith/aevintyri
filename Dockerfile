FROM alpine:latest

RUN apk add --no-cache \
  ca-certificates \
  build-base \
  git \
  make;

RUN git clone git://c9x.me/qbe.git; \
  cd qbe; make; make install;

RUN git clone https://git.sr.ht/~sircmpwn/scdoc; \
  cd scdoc; make; make install;

RUN git clone https://git.sr.ht/~sircmpwn/harec; \
  cd harec; mkdir build; cd build; ../configure; make; make install;

RUN git clone https://git.sr.ht/~sircmpwn/hare; \
  cd hare; cp config.example.mk config.mk; make; make install;
