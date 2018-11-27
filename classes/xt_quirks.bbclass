def get_tarfname(location, d):
    return os.path.join(os.path.dirname(location),
        str(d.getVar('PN')) + "-" + str(d.getVar('PV')) + "-" +
        os.path.basename(location) + ".tar.gz")

def create_tarfile(location, d):
    import tarfile

    arcname = get_tarfname(location, d)
    tar = tarfile.open(arcname, "w:gz")
    tar.add(location, os.path.basename(location))
    tar.close()
    return arcname

def check_url_or_pack(url, type, location, d):
    if type.lower() != 'file':
        return url
    if not os.path.isdir(location):
        return url
    new_location = create_tarfile(location, d)
    return url.replace(location, new_location)

def remove_tarfile(url, type, location, d):
    if type.lower() != 'file':
        return
    if not os.path.isdir(location):
        return
    arcname = get_tarfname(location, d)
    if os.path.exists(arcname):
        os.remove(arcname)

addtask unpack_xt_extras after do_unpack before do_configure
python do_unpack_xt_extras() {
    bb.debug(1, "Unpacking Xen-troops extras")
    # all the sources in SRC_URI have been unpacked already, clean it
    d.setVar("SRC_URI", "")
    # now deliver all the static extras into inner build system
    urls = (d.getVar("XT_QUIRK_UNPACK_SRC_URI") or "").split()
    
    if xt_is_reconstruct(d):
        versions_path = os.path.join(d.getVar("XT_RECONSTRUCT_DIR"), d.getVar("PN"))
        d.appendVar("FILESEXTRAPATHS", versions_path or "")
        urls.append("file://" + "build-versions.inc" + ";subdir=repo/build/conf")

    for url in urls:
        type, _, location, _, _, _ = bb.fetch.decodeurl(url)
        item = check_url_or_pack(url, type, location, d) + " "
        d.appendVar("SRC_URI", item or "")

    # now call real unpacker to do the rest
    bb.build.exec_func('base_do_unpack', d)

    # remove the archives we created
    urls = (d.getVar("XT_QUIRK_UNPACK_SRC_URI") or "").split()
    for url in urls:
        type, _, location, _, _, _ = bb.fetch.decodeurl(url)
        remove_tarfile(url, type, location, d)
}

python do_patch_prepend() {
    d.appendVar("SRC_URI", "\n")
    urls = (d.getVar("XT_QUIRK_PATCH_SRC_URI") or "").split()
    d.appendVar("SRC_URI", d.getVar("XT_QUIRK_PATCH_SRC_URI") or "")
    try:
        fetcher = bb.fetch2.Fetch(urls, d)
        fetcher.download()
    except bb.fetch2.BBFetchException as e:
        bb.fatal(str(e))

}

def xt_is_reconstruct(d):
    bb.debug(1, "Checking if build reconstruction was requested")
    reconstruct_dir = d.getVar("XT_RECONSTRUCT_DIR") or ""

    if not reconstruct_dir:
        return False

    pn = d.getVar("PN") or ""
    if not os.path.isdir(os.path.join(reconstruct_dir, pn)):
        bb.debug(1, "Nothing to reconstruct")
        return False
    return True

addtask xt_config_reconstruct after do_configure before do_compile
python do_xt_config_reconstruct() {
    if not xt_is_reconstruct(d):
        return

    f = os.path.join(d.getVar("S" or ""), "build/conf/local.conf")
    base_update_conf_value(f, "require", "build-versions.inc")
}

addtask xt_reconstruct_repo before do_fetch
python do_xt_reconstruct_repo() {
    bb.debug(1, "Replacing repo:// with build history")
    # remeber the original SRC_URI
    src_uri = (d.getVar("SRC_URI") or "").split()
    # remove all from the recipe's SRC_URI
    d.setVar("SRC_URI", "")
    for src in src_uri:
        type, _, location,_ , _,_ = bb.fetch.decodeurl(src)
        if type != 'repo':
            print("SRC - ", src)
            d.appendVar("SRC_URI", src)
        else:
            #val = "repo://gitpct.epam.com/epmd-aepr/build-history" + d.getVar("XT_RECONSTRUCT_DIR" or "") + d.getVar("PN" or "") + "meta-revs.xml"
            #repo://github.com/xen-troops/manifests;protocol=https;branch=master;manifest=prod_devel/domd.xml;scmdata=keep
            #git@gitpct.epam.com:epmd-aepr/build-history.git
            val =  "repo://git@gitpct.epam.com/epmd-aepr/build-history;branch=master;manifest=dailybuild/2018-11-16/prod-devel/salvator-xs-h3/16-15-25/meta-revs.xml;scmdata=keep"
            d.appendVar("SRC_URI", val)
            print("SRC_URI___ - ", d.getVar("SRC_URI" or ""))
            #print("SRC_REPO - ", src)
}
